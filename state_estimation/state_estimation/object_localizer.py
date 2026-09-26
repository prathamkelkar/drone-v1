import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from sensor_msgs.msg import Image, CameraInfo
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

        self.image_sub = self.create_subscription(Image, '/camera/camera_info', self.camera_info_callback, qos_profile=qos)
        self.detection_suv = self.create_subscription(Detection2D, '/detected_object', self.detection_callback, qos)

    def camera_info_callback(self, msg: CameraInfo):
        # focal length
        fx = msg.k[0]
        fy = msg.k[4]

        # principal point
        cx = msg.k[2]
        cy = msg.k[5]

    def detection_callback(self, msg: Detection2D):

        # center of the coordinates
        u = msg.bbox.center.position.x
        v = msg.bbox.center.position.y

        # width and height of the bounding box for the image
        w = msg.bbox.size_x
        h = msg.bbox.size_y



def main(args=None):
    rclpy.init(args=args)
    node = Object_Localizer()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()