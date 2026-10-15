import time
import cv2
import numpy as np

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from sensor_msgs.msg import Image
from vision_msgs.msg import Detection2D, ObjectHypothesisWithPose
from cv_bridge import CvBridge, CvBridgeError

class HSVPerceptionNode(Node):
    def __init__(self):
        super().__init__('hsv_perception_node')

        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,  # always work on the newest frame, drop stale ones
        )

        # tunable parameter: ros2 param set /hsv_perception_node hsv_lower "[5,120,80]"
        self.declare_parameter('hsv_lower', [5, 150, 100])
        self.declare_parameter('hsv_upper', [25, 255, 255])
        self.declare_parameter('scale', 0.5)
        self.declare_parameter('min_area_px', 30.0)
        self.declare_parameter('min_fill', 0.6)
        self.declare_parameter('publish_debug', False)

        self.bridge = CvBridge()
        self.kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3,3))

        self.image_sub = self.create_subscription(Image, '/camera/image_raw', self.image_callback, qos)
        self.detection_pub = self.create_publisher(Detection2D, '/detected_object', qos)
        self.debug_pub = self.create_publisher(Image, '/perception/debug_mask', qos)

    def image_callback(self, msg: Image):

        # start of the per-frame timer
        t0 = time.perf_counter()

        try:
            # converting the ROS image message into a numpy array that opencv can use
            # opencv default is bgr
            # rgb8 avoids a channel-swap copy if the bridge already delivers rgb8
            frame = self.bridge.imgmsg_to_cv2(msg, desired_encoding='rgb8')
        except CvBridgeError as e:
            self.get_logger().error(f'CVBridge error: {e}')
            return

        # shrinking the image
        s = float(self.get_parameter('scale').value)
        # INTER_AREA averages the source pizels that map onto each output pixel
        small = cv2.resize(frame, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        # converting rgb to hsv
        hsv = cv2.cvtColor(small, cv2.COLOR_RGB2HSV)

        # checking for hsv values within range
        lower = np.array(self.get_parameter('hsv_lower').value, dtype=np.uint8)
        upper = np.array(self.get_parameter('hsv_upper').value, dtype=np.uint8)

        mask = cv2.inRange(hsv, lower, upper)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, self.kernel) # remove specks
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, self.kernel) # fill small holes

        # finding blobs
        if self.get_parameter('publish_debug').value:
            dbg = self.bridge.cv2_to_imgmsg(mask, encoding='mono8')
            dbg.header = msg.header
            self.debug_pub.publish(dbg)

        contours,_ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        min_area = float(self.get_parameter('min_area_px').value)
        min_fill = float(self.get_parameter('min_fill').value)

        best, best_area, best_fill = None, 0.0, 0.0

        # picking the best blob -> the largest one that is round enough
        for c in contours:
            area = cv2.contourArea(c)
            if area < min_area or area <= best_area:
                continue
            # roundness test
            (x, y), r = cv2.minEnclosingCircle(c)
            fill = area / (np.pi * r * r + 1e-9)

            if fill < min_fill:  # rejects non-round blobs
                continue

            best, best_area, best_fill = (x, y, r), area, fill

        # publish only the best blob, once per frame
        if best is None:
            return

        x, y, r = best
        inv = 1.0 / s  # scale back to full-resolution pixels
        d = 2.0 * r * inv # diameter, used as w in Z = fx*W/w

        det = Detection2D()
        det.header = msg.header
        det.bbox.center.position.x = float(x * inv)
        det.bbox.center.position.y = float(y * inv)
        # circle's bounding box is a d by d square
        det.bbox.size_x = float(d)
        det.bbox.size_y = float(d)

        hyp = ObjectHypothesisWithPose()
        hyp.hypothesis.class_id = 'ball'
        hyp.hypothesis.score = float(best_fill)
        det.results.append(hyp)
        self.detection_pub.publish(det)

        self.get_logger().info(
            f'proc {1000 * (time.perf_counter() - t0):.1f} ms',
            throttle_duration_sec=2.0
        )

def main(args=None):
    rclpy.init(args=args)
    node = HSVPerceptionNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()

if __name__ == "__main__":
    main()