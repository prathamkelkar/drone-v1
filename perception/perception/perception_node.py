import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from sensor_msgs.msg import Image
from cv_bridge import CvBridge, CvBridgeError
from vision_msgs.msg import Detection2D, ObjectHypothesisWithPose

from ultralytics import YOLO
import numpy as np


class PerceptionNode(Node):
    def __init__(self):
        super().__init__('perception_node')

        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1
        )

        self.image_sub = self.create_subscription(Image, '/camera/image_raw', self.image_callback, qos)

        self.bridge = CvBridge()
        self.model = YOLO('yolov8n.pt')

        self.confidence_threshold = 0.5
        self.detection_pub = self.create_publisher(Detection2D, '/detected_object', qos)



    def image_callback(self, msg):
        try:
            cv_image = self.bridge.imgmsg_to_cv2(msg, desired_encoding='bgr8')
            self.get_logger().info('Received image of size: {}x{}'.format(cv_image.shape[1], cv_image.shape[0]))

            results = self.model(cv_image, verbose=False, conf=self.confidence_threshold)

            result = results[0]
            best_conf = 0.0
            best_box = None

            for box in result.boxes:
                confidence = float(box.conf[0])

                if confidence < self.confidence_threshold:
                    continue

                if confidence > best_conf:
                    best_conf = confidence
                    best_box = box

            if best_box is None:
                self.get_logger().info('No detections above confidence threshold.')
                return

            class_id = int(best_box.cls[0])
            class_name = self.model.names[class_id]

            self.get_logger().info('Best detection: Class: {}, Confidence: {:.2f}'.format(class_name, best_conf))

            # extracting pixel bounding box coordinates
            x1, y1, x2, y2 = best_box.xyxy[0].tolist()
            w = x2 - x1
            h = y2 - y1
            center_x = x1 + w / 2.0
            center_y = y1 + h / 2.0

            # packaging the detection into a Detection2D message
            detection_msg = Detection2D()
            detection_msg.header = msg.header
            detection_msg.bbox.center.position.x = center_x
            detection_msg.bbox.center.position.y = center_y
            detection_msg.bbox.size_x = float(w)
            detection_msg.bbox.size_y = float(h)

            hypothesis = ObjectHypothesisWithPose()
            hypothesis.hypothesis.class_id = class_name
            hypothesis.hypothesis.score = best_conf
            detection_msg.results.append(hypothesis)

            # publishing the detection message
            self.detection_pub.publish(detection_msg)

        except CvBridgeError as e:
            self.get_logger().error('CvBridge Error: {}'.format(e))

def main(args=None):
    rclpy.init(args=args)
    node = PerceptionNode()  # or whatever your class is named
    rclpy.spin(node)
    node.destroy_node() # 
    rclpy.shutdown()

if __name__ == '__main__':
    main()