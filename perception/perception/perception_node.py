import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from sensor_msgs.msg import Image
from cv_bridge import CvBridge, CvBridgeError
from vision_msgs.msg import Detection2DArray

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

    def image_callback(self, msg):
        try:
            bridge = CvBridge()
            cv_image = bridge.imgmsg_to_cv2(msg, desired_encoding='bgr8')
            self.get_logger().info('Received image of size: {}x{}'.format(cv_image.shape[1], cv_image.shape[0]))
        except CvBridgeError as e:
            self.get_logger().error('CvBridge Error: {}'.format(e))