import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from sensor_msgs.msg import Image, CameraInfo
from vision_msgs.msg import Detection2D
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

        self.image_sub = self.create_subscription(CameraInfo, '/camera/camera_info', self.camera_info_callback, qos_profile=qos)
        self.detection_suv = self.create_subscription(Detection2D, '/detected_object', self.detection_callback, qos)

        self.pose_pub = self.create_publisher(PoseStamped, 'estimation/pose_object_raw', qos)

        # True: transform each detection using the drone's pose at the moment
        # the image was captured. False: use the latest pose (old behaviour);
        # kept so the two can be compared.
        self.declare_parameter('use_image_stamp', True)

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

        # The detection carries the image's capture time (perception copies
        # the image header). Detections arrive ~0.2-0.3 s after capture, so
        # transforming with the *latest* drone pose would inject an error of
        # about drone_velocity * latency (plus a tilt error). Ask tf for the
        # pose at capture time instead; it interpolates between the two
        # nearest recorded transforms.
        query_time = rclpy.time.Time()  # 0 = latest available
        if self.get_parameter('use_image_stamp').value:
            capture_time = rclpy.time.Time.from_msg(msg.header.stamp)
            if self.tf_buffer.can_transform('world', self.camera_frame, capture_time):
                query_time = capture_time
            else:
                # capture time not (yet / any longer) covered by the tf buffer
                self.get_logger().warn(
                    'No tf at image capture time, using latest pose instead',
                    throttle_duration_sec=2.0)

        if not self.tf_buffer.can_transform('world', self.camera_frame, query_time):
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

        X = (u - self.cx) * Z / self.fx
        Y = (v - self.cy) * Z / self.fy

        camera_pose = PoseStamped()

        camera_pose.header.stamp = query_time.to_msg()
        camera_pose.header.frame_id = self.camera_frame
        camera_pose.pose.position.x = X
        camera_pose.pose.position.y = Y
        camera_pose.pose.position.z = Z
        camera_pose.pose.orientation.w = 1.0

        try:
            # Small nonzero timeout gives tf a brief grace window if the
            # exact/interpolatable transform hasn't landed yet, without
            # blocking the executor for a full second like the original
            # timeout=1.0 did (that's what caused the earlier deadlock).
            world_pose = self.tf_buffer.transform(
                camera_pose, 'world', timeout=rclpy.duration.Duration(seconds=0.05)
            )
            self.pose_pub.publish(world_pose)
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