"""ROS 2 hybrid localizer: one monocular detection + an aligned depth image -> 3D ball position.

Bearing always comes from the monocular camera. Range comes from the depth camera inside
depth_max_m (about 4 m), fused with the monocular range. Beyond that, monocular range only.
The maths lives in hybrid_geometry.py.

The depth image must be aligned to the colour image (RealSense align_depth.enable:=true).
"""
import numpy as np

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy
from message_filters import Subscriber, ApproximateTimeSynchronizer
from cv_bridge import CvBridge, CvBridgeError

from geometry_msgs.msg import PoseStamped
from sensor_msgs.msg import CameraInfo, Image
from std_msgs.msg import Float64
from vision_msgs.msg import Detection2D

from hybrid_geometry import HybridConfig, localize_hybrid


def _best_effort(depth):
    # BEST_EFFORT subscribers accept both RELIABLE and BEST_EFFORT publishers, so they
    # work with Gazebo, RealSense and our own detectors without a QoS mismatch.
    return QoSProfile(
        reliability=ReliabilityPolicy.BEST_EFFORT,
        durability=DurabilityPolicy.VOLATILE,
        history=HistoryPolicy.KEEP_LAST,
        depth=depth,
    )


class HybridLocalizer(Node):
    def __init__(self):
        super().__init__('hybrid_localizer')

        self.declare_parameter('detection_topic', '/mono/detected_object')
        self.declare_parameter('depth_topic', '/camera/aligned_depth_to_color/image_raw')
        self.declare_parameter('camera_info_topic', '/camera/color/camera_info')
        self.declare_parameter('output_topic', '/estimation/pose_object_raw')
        self.declare_parameter('sigma_topic', '/estimation/depth_sigma')
        self.declare_parameter('ball_width_m', 0.22)
        self.declare_parameter('depth_min_m', 0.2)
        self.declare_parameter('depth_max_m', 4.0)
        self.declare_parameter('depth_k', 0.002)
        self.declare_parameter('sigma_width_px', 1.0)
        self.declare_parameter('sigma_width_rel', 0.1)
        self.declare_parameter('sample_radius_frac', 0.5)
        self.declare_parameter('gate_sigmas', 3.0)
        self.declare_parameter('min_depth_pixels', 10)
        self.declare_parameter('sync_slop_s', 0.02)
        self.declare_parameter('sync_queue', 10)

        g = lambda name: self.get_parameter(name).value
        self.cfg = HybridConfig(
            ball_width_m=float(g('ball_width_m')),
            depth_min_m=float(g('depth_min_m')),
            depth_max_m=float(g('depth_max_m')),
            depth_k=float(g('depth_k')),
            sigma_width_px=float(g('sigma_width_px')),
            sigma_width_rel=float(g('sigma_width_rel')),
            sample_radius_frac=float(g('sample_radius_frac')),
            gate_sigmas=float(g('gate_sigmas')),
            min_depth_pixels=int(g('min_depth_pixels')),
        )

        self.bridge = CvBridge()
        self.K = None
        self.D = None
        self.size = None        # (width, height) of the colour image
        self.frame_id = None

        self.create_subscription(CameraInfo, g('camera_info_topic'), self._on_info, _best_effort(1))

        sync_depth = int(g('sync_queue'))
        self.det_sub = Subscriber(self, Detection2D, g('detection_topic'),
                                  qos_profile=_best_effort(sync_depth))
        self.depth_sub = Subscriber(self, Image, g('depth_topic'),
                                    qos_profile=_best_effort(sync_depth))
        self.sync = ApproximateTimeSynchronizer(
            [self.det_sub, self.depth_sub],
            queue_size=sync_depth,
            slop=float(g('sync_slop_s')))
        self.sync.registerCallback(self._on_pair)

        self.pose_pub = self.create_publisher(PoseStamped, g('output_topic'), _best_effort(1))
        self.sigma_pub = self.create_publisher(Float64, g('sigma_topic'), _best_effort(1))

        self.get_logger().info('Hybrid localizer started; waiting for camera_info')

    # --- inputs ------------------------------------------------------------
    def _on_info(self, msg):
        if self.K is None:
            self.K = np.asarray(msg.k, dtype=np.float64).reshape(3, 3)
            self.D = np.asarray(msg.d, dtype=np.float64)
            self.size = (int(msg.width), int(msg.height))
            self.frame_id = msg.header.frame_id
            self.get_logger().info(
                f'Mono intrinsics: f={self.K[0, 0]:.1f} px, size {self.size}, frame "{self.frame_id}"')

    def _depth_metres(self, msg):
        img = self.bridge.imgmsg_to_cv2(msg, desired_encoding='passthrough')
        if msg.encoding == '16UC1':        # RealSense default: millimetres
            return img.astype(np.float32) * 0.001
        if msg.encoding == '32FC1':        # Gazebo and most sims: metres
            return img.astype(np.float32)
        raise ValueError(f'unsupported depth encoding {msg.encoding!r}')

    @staticmethod
    def _bbox(det):
        return (det.bbox.center.position.x, det.bbox.center.position.y, det.bbox.size_x)

    # --- main callback -----------------------------------------------------
    def _on_pair(self, det_msg, depth_msg):
        if self.K is None:
            self.get_logger().warn('Waiting for camera_info', throttle_duration_sec=5.0)
            return
        if not det_msg.results:
            return

        u, v, w = self._bbox(det_msg)

        depth = None
        try:
            depth = self._depth_metres(depth_msg)
        except (CvBridgeError, ValueError) as e:
            self.get_logger().warn(f'Depth unusable, using monocular range only: {e}',
                                   throttle_duration_sec=5.0)
        if depth is not None and (depth.shape[1], depth.shape[0]) != self.size:
            self.get_logger().warn(
                f'Depth {depth.shape[1]}x{depth.shape[0]} does not match colour {self.size}; '
                f'depth is not aligned, using monocular range only', throttle_duration_sec=5.0)
            depth = None

        res = localize_hybrid(self.K, self.D, u, v, w, depth, self.cfg)
        if res is None:
            return

        out = PoseStamped()
        out.header.stamp = det_msg.header.stamp
        out.header.frame_id = self.frame_id
        out.pose.position.x = res['X']
        out.pose.position.y = res['Y']
        out.pose.position.z = res['Z']
        out.pose.orientation.w = 1.0
        self.pose_pub.publish(out)

        sig = Float64()
        sig.data = res['sigma_Z']
        self.sigma_pub.publish(sig)

        self.get_logger().debug(f"range source={res['source']} Z={res['Z']:.3f} m",
                                throttle_duration_sec=1.0)


def main(args=None):
    rclpy.init(args=args)
    node = HybridLocalizer()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()