"""ROS 2 stereo localizer node.

Subscribes to one Detection2D per camera (already time-synchronised by the synchroniser
below), undistorts and rectifies the centres, triangulates, and publishes the ball position.
The maths lives in stereo_geometry.py. This file only wires ROS to it.

Modes
-----
raw       (default) CameraInfo is for the RAW camera. Calibration file must give R1, P1, R2, P2
          (cv2.stereoRectify output). Points are undistorted and rectified every frame.
rectified CameraInfo is for already-rectified images (e.g. image_proc output). No undistortion.
          Output is in the rectified left optical frame, which is named by the CameraInfo.
"""
import numpy as np
import yaml

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy
from message_filters import Subscriber, ApproximateTimeSynchronizer

from geometry_msgs.msg import PoseStamped
from sensor_msgs.msg import CameraInfo
from std_msgs.msg import Float64
from vision_msgs.msg import Detection2D

from stereo_geometry import StereoModel, validate_model, localize


def _best_effort(depth):
    # BEST_EFFORT subscribers accept both RELIABLE and BEST_EFFORT publishers, so they
    # work with Gazebo, RealSense and our own detectors without a QoS mismatch.
    return QoSProfile(
        reliability=ReliabilityPolicy.BEST_EFFORT,
        durability=DurabilityPolicy.VOLATILE,
        history=HistoryPolicy.KEEP_LAST,
        depth=depth,
    )


class StereoLocalizer(Node):
    def __init__(self):
        super().__init__('stereo_localizer')

        self.declare_parameter('mode', 'raw')
        self.declare_parameter('calibration_file', '')
        self.declare_parameter('left_detection_topic', '/left/detected_object')
        self.declare_parameter('right_detection_topic', '/right/detected_object')
        self.declare_parameter('left_info_topic', '/left/camera_info')
        self.declare_parameter('right_info_topic', '/right/camera_info')
        self.declare_parameter('output_topic', '/estimation/pose_object_raw')
        self.declare_parameter('depth_sigma_topic', '/estimation/depth_sigma')
        self.declare_parameter('sigma_disparity_px', 0.5)
        self.declare_parameter('max_row_diff_px', 3.0)
        self.declare_parameter('min_disparity_px', 1.0)
        self.declare_parameter('min_baseline_m', 0.02)
        self.declare_parameter('sync_slop_s', 0.01)
        self.declare_parameter('sync_queue', 10)

        self.mode = str(self.get_parameter('mode').value)
        if self.mode not in ('raw', 'rectified'):
            raise ValueError(f"mode must be 'raw' or 'rectified', got {self.mode!r}")

        self.calib = {}
        if self.mode == 'raw':
            self.calib = self._load_calibration(str(self.get_parameter('calibration_file').value))

        self.left_info = None
        self.right_info = None
        self.model = None
        self.frame_id = None

        self.create_subscription(CameraInfo, self.get_parameter('left_info_topic').value,
                                 self._on_left_info, _best_effort(1))
        self.create_subscription(CameraInfo, self.get_parameter('right_info_topic').value,
                                 self._on_right_info, _best_effort(1))

        sync_depth = int(self.get_parameter('sync_queue').value)
        self.left_sub = Subscriber(self, Detection2D,
                                   self.get_parameter('left_detection_topic').value,
                                   qos_profile=_best_effort(sync_depth))
        self.right_sub = Subscriber(self, Detection2D,
                                    self.get_parameter('right_detection_topic').value,
                                    qos_profile=_best_effort(sync_depth))
        self.sync = ApproximateTimeSynchronizer(
            [self.left_sub, self.right_sub],
            queue_size=sync_depth,
            slop=float(self.get_parameter('sync_slop_s').value))
        self.sync.registerCallback(self._on_pair)

        self.pose_pub = self.create_publisher(PoseStamped,
                                              self.get_parameter('output_topic').value,
                                              _best_effort(1))
        self.sigma_pub = self.create_publisher(Float64,
                                               self.get_parameter('depth_sigma_topic').value,
                                               _best_effort(1))

        self.get_logger().info(f"Stereo localizer started in '{self.mode}' mode; waiting for CameraInfo")

    # --- calibration -------------------------------------------------------
    def _load_calibration(self, path):
        if not path:
            self.get_logger().error("mode 'raw' needs the 'calibration_file' parameter")
            return {}
        try:
            with open(path, 'r') as fh:
                data = yaml.safe_load(fh) or {}
        except OSError as e:
            self.get_logger().error(f'Cannot read calibration file {path!r}: {e}')
            return {}
        self.get_logger().info(f'Loaded calibration from {path}')
        return data

    def _matrix(self, name, rows, cols):
        if name not in self.calib:
            raise ValueError(f"calibration file has no '{name}' entry")
        vals = np.asarray(self.calib[name], dtype=np.float64).reshape(-1)
        if vals.size != rows * cols:
            raise ValueError(f"'{name}' needs {rows * cols} numbers, has {vals.size}")
        return vals.reshape(rows, cols)

    def _on_left_info(self, msg):
        if self.left_info is None:
            self.left_info = msg
            self._try_build_model()

    def _on_right_info(self, msg):
        if self.right_info is None:
            self.right_info = msg
            self._try_build_model()

    def _try_build_model(self):
        if self.model is not None or self.left_info is None or self.right_info is None:
            return
        K_l = np.asarray(self.left_info.k, dtype=np.float64).reshape(3, 3)
        K_r = np.asarray(self.right_info.k, dtype=np.float64).reshape(3, 3)
        D_l = np.asarray(self.left_info.d, dtype=np.float64)
        D_r = np.asarray(self.right_info.d, dtype=np.float64)
        try:
            if self.mode == 'rectified':
                if np.any(np.abs(D_l) > 0) or np.any(np.abs(D_r) > 0):
                    self.get_logger().warn(
                        "mode 'rectified' but CameraInfo.d is non-zero: points are NOT undistorted. "
                        "Use mode 'raw' with a calibration file.")
                model = StereoModel(
                    P_left=np.asarray(self.left_info.p, np.float64).reshape(3, 4),
                    P_right=np.asarray(self.right_info.p, np.float64).reshape(3, 4),
                    K_left=K_l, D_left=D_l, K_right=K_r, D_right=D_r,
                    R_left=np.eye(3), R_right=np.eye(3), undistort=False)
                frame = self.left_info.header.frame_id
            else:
                model = StereoModel(
                    P_left=self._matrix('P1', 3, 4),
                    P_right=self._matrix('P2', 3, 4),
                    K_left=K_l, D_left=D_l, K_right=K_r, D_right=D_r,
                    R_left=self._matrix('R1', 3, 3),
                    R_right=self._matrix('R2', 3, 3),
                    undistort=True)
                frame = self.left_info.header.frame_id   # raw left optical frame
            validate_model(model, float(self.get_parameter('min_baseline_m').value))
        except ValueError as e:
            self.get_logger().error(f'Calibration rejected: {e}', throttle_duration_sec=10.0)
            return

        self.model = model
        self.frame_id = frame
        self.get_logger().info(
            f'Stereo ready: baseline {model.B:.4f} m, f {model.f:.1f} px, output frame "{frame}"')

    # --- detections --------------------------------------------------------
    @staticmethod
    def _centre(det):
        return (det.bbox.center.position.x, det.bbox.center.position.y)

    def _on_pair(self, left_msg, right_msg):
        if self.model is None:
            self.get_logger().warn('No valid calibration yet, dropping detections',
                                   throttle_duration_sec=5.0)
            return
        if not left_msg.results or not right_msg.results:
            return

        res = localize(
            self.model,
            [self._centre(left_msg)],
            [self._centre(right_msg)],
            sigma_d_px=float(self.get_parameter('sigma_disparity_px').value),
            max_row_diff=float(self.get_parameter('max_row_diff_px').value),
            min_disparity=float(self.get_parameter('min_disparity_px').value))
        if res is None:
            self.get_logger().debug('No valid stereo pair this frame')
            return

        out = PoseStamped()
        # Stamp from the LEFT detection; the synchroniser has already matched the pair in time.
        out.header.stamp = left_msg.header.stamp
        out.header.frame_id = self.frame_id
        out.pose.position.x = res['X']
        out.pose.position.y = res['Y']
        out.pose.position.z = res['Z']
        out.pose.orientation.w = 1.0
        self.pose_pub.publish(out)

        sig = Float64()
        sig.data = res['sigma_Z']
        self.sigma_pub.publish(sig)


def main(args=None):
    rclpy.init(args=args)
    node = StereoLocalizer()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()