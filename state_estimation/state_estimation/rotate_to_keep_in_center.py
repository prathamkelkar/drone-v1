
import rclpy
from rclpy.node import Node
from vision_msgs.msg import Detection2D
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy
from geometry_msgs.msg import Vector3
from sensor_msgs.msg import Image, CameraInfo
import math



class Rotate(Node):
    def __init__(self):
        super().__init__('rotate')

        self.pixel_sub = self.create_subscription(Detection2D, '/detected_object', self.rotate_callback, 10)
        self.image_sub = self.create_subscription(CameraInfo, '/camera/camera_info', self.camera_info_callback)
        self.rotate_pub = self.create_publisher()

        self.previous_x = None
        self.previous_y = None

        self.focal_length = None

    def camera_info_callback(self, msg:CameraInfo):
        # focal length
        self.fx = msg.k[0]
        self.fy = msg.k[4]

        # principal point
        self.cx = msg.k[2]
        self.cy = msg.k[5]

        self.camera_frame = msg.header.frame_id

    def rotate_callback(self, msg:Detection2D):

        msg_send = Vector3()

        if self.previous_x == None and self.previous_y == None:
            msg_send.x = 0
            msg_send.y = 0
            msg_send.z = 0
            return msg_send

        x = msg.bbox.center.position.x
        y = msg.bbox.center.position.y

        change_x = abs(self.previous_x - x)
        change_y = abs(self.previous_y - y)
        rotate_x = math.atan(change_x / self.fx)
        rotate_y = math.atan(change_y / self.fy)

        msg_send.x = rotate_y
        msg_send.y = 0
        msg_send.z = rotate_x

        return msg_send

def main(args=None):
    rclpy.init(args=args)
    node = Rotate()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


        



        



