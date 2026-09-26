import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from sensor_msgs.msg import Image, CameraInfo
from vision_msgs.msg import Detection2D, ObjectHypothesisWithPose
from geometry_msgs.msg import PoseStamped

import tf2_ros
import tf2_geometry_msgs

KNOWN_OBJECT_WIDTH = 0.22

class Object_Localizer(Node):
    def __init__(self):
        super().__init__('object_localizer')

        qos = QoSProfile(
                    reliability=ReliabilityPolicy.BEST_EFFORT,
                    durability=DurabilityPolicy.VOLATILE,
                    history=HistoryPolicy.KEEP_LAST,
                    depth=1
        )

        self.fx = None
        self.fy = None
        self.cx = None
        self.cy = None

        # holds the coordinate system the camera's data is expressed in
        self.camera_frame = None

        self.image_sub = self.create_subscription(Image, '/camera/camera_info', self.camera_info_callback, qos_profile=qos)
        self.detection_suv = self.create_subscription(Detection2D, '/detected_object', self.detection_callback, qos)

        self.pose_pub = self.create_publisher(PoseStamped, 'estimation/pose_object_raw', qos)

        # buffer stores and manages all transforms over time
        self.tf_buffer = tf2_ros.Buffer()
        # listener receives those transformations from the network and feeds them into the buffer
        self.tf_listener = tf2_ros.TransformListener(self.tf_buffer, self)

    def camera_info_callback(self, msg: CameraInfo):
        # focal length
        self.fx = msg.k[0]
        self.fy = msg.k[4]

        # principal point
        self.cx = msg.k[2]
        self.cy = msg.k[5]

        self.camera_frame = msg.header.frame_id

    def detection_callback(self, msg: Detection2D):

        # not processing detections until all intrinsic information is received
        if self.camera_frame is None:
            self.get_logger().warn('No camera info received yet -> skipping detection')
            return

        # center of the coordinates
        u = msg.bbox.center.position.x
        v = msg.bbox.center.position.y

        # width and height of the bounding box for the image
        w = msg.bbox.size_x
        h = msg.bbox.size_y

        # guarding against a zero-width/degenerate box
        if w <= 0:
            return

        Z = (self.fx * KNOWN_OBJECT_WIDTH) / w

        X = (u - self.cx) / w * KNOWN_OBJECT_WIDTH
        Y = (v - self.cy) / w * KNOWN_OBJECT_WIDTH

        camera_pose = PoseStamped()

        camera_pose.header.stamp = msg.header.stamp
        camera_pose.header.frame_id = self.camera_frame
        camera_pose.pose_position.x = X
        camera_pose.pose.position.Y = Y
        camera_pose.pose.position.Z = Z
        camera_pose.pose.orientation.w = 1.0

        try:
            world_pose = self.tf_buffer.transform(
                camera_pose, 'world', rclpy.duration.Duration(seconds=0.1)
            )
            self.pose_pub(world_pose)

        except (tf2_ros.LookupException, tf2_ros.ConnectivityException, tf2_ros.ExtrapolationException) as e:
            self.get_logger().warn(f'Transform failed: {e}')


def main(args=None):
    rclpy.init(args=args)
    node = Object_Localizer()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()