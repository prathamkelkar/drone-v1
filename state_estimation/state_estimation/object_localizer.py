import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from sensor_msgs.msg import Image
from vision_msgs.msg import Detection2D, ObjectHypothesisWithPose



class Object_Localizer(Node):
    def __init__(self):
        super().__init__('object_localizer')

        qos = QoSProfile(
                    reliability=ReliabilityPolicy.BEST_EFFORT,
                    durability=DurabilityPolicy.VOLATILE,
                    history=HistoryPolicy.KEEP_LAST,
                    depth=1
        )

        self.image_sub = self.create_subscription(Image, '/camera/image_raw', self.image_callback, qos_profile=qos)
        self.detection_suv = self.create_subscription(Detection2D, '/detected_object', self.detection_callback, qos)

    def image_callback(self):
        pass

    def detection_callback(self):
        pass

def main(args=None):
    rclpy.init(args=args)
    node = Object_Localizer()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()