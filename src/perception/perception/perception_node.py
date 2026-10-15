import os
import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from sensor_msgs.msg import Image
from cv_bridge import CvBridge, CvBridgeError
from vision_msgs.msg import Detection2D, ObjectHypothesisWithPose

from ultralytics import YOLO
import numpy as np
import torch


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
        # Stock YOLO11n (80 COCO classes). Absolute path so the node works
        # from any cwd. ~/ros2_ws/best.pt (fine-tuned: 'ball', 'carton',
        # 'plastic_bottle') can be selected with the model_path parameter.
        self.declare_parameter('model_path', os.path.expanduser('~/ros2_ws/yolo11n.pt'))
        self.model = YOLO(self.get_parameter('model_path').value)

        # 'cuda:0' runs YOLO on the GPU; falls back to CPU if CUDA isn't
        # available so the node still works on machines without a GPU.
        self.declare_parameter('device', 'cuda:0')
        self.device = self.get_parameter('device').value
        if self.device.startswith('cuda') and not torch.cuda.is_available():
            self.get_logger().warn(f'device {self.device!r} requested but CUDA is unavailable, using cpu')
            self.device = 'cpu'
        self.model.to(self.device)
        # FP16 is ~2x faster on RTX GPUs; not supported on CPU
        self.precision = 16 if self.device.startswith('cuda') else 32
        if self.precision == 16:
            self.get_logger().info(f'YOLO running on GPU: {torch.cuda.get_device_name(self.device)}')
        else:
            self.get_logger().info('YOLO running on CPU')

        self.confidence_threshold = 0.25
        # The drone's own propellers show up in the frame and can be
        # misclassified with high confidence — only accept the class we're
        # actually tracking. Must be one of self.model.names.
        self.declare_parameter('target_class', 'sports ball')
        self.target_class = self.get_parameter('target_class').value
        if self.target_class not in self.model.names.values():
            raise ValueError(f'target_class {self.target_class!r} not in model classes '
                             f'{list(self.model.names.values())}')
        self.get_logger().info(f'Tracking {self.target_class!r} with {self.get_parameter("model_path").value}')
        self.detection_pub = self.create_publisher(Detection2D, '/detected_object', qos)



    def image_callback(self, msg):
        try:
            cv_image = self.bridge.imgmsg_to_cv2(msg, desired_encoding='bgr8')
            self.get_logger().info('Received image of size: {}x{}'.format(cv_image.shape[1], cv_image.shape[0]))

            results = self.model(cv_image, verbose=False, conf=self.confidence_threshold,
                                 device=self.device, quantize=self.precision)

            result = results[0]
            best_conf = 0.0
            best_box = None

            for box in result.boxes:
                confidence = float(box.conf[0])

                if confidence < self.confidence_threshold:
                    continue

                if self.model.names[int(box.cls[0])] != self.target_class:
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
    node = PerceptionNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()