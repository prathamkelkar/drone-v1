#!/usr/bin/env python3
import math

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from vision_msgs.msg import Detection2D
from geometry_msgs.msg import Vector3
from sensor_msgs.msg import CameraInfo


class RotateCommand(Node):
    """
    Computes the angle the camera/gimbal would need to turn, right now,
    to bring the detected object to the center of the frame.

    This is a one-shot calculation per detection (not a rate, not a
    frame-to-frame delta) — the angle is measured from the camera's
    optical axis (the principal point, cx/cy) to the current detection,
    using the standard pinhole relationship:

        angle = atan((pixel - principal_point) / focal_length)

    Positive x (yaw) means the object is to the right of center —
    turn right (positive yaw, by the usual right-hand convention about
    the camera's down/forward axis; flip sign here if your convention
    differs).
    Positive y (pitch) means the object is below center — pitch down.
    """

    def __init__(self):
        super().__init__('rotate_command')

        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )

        self.pixel_sub = self.create_subscription(
            Detection2D, '/detected_object', self.rotate_callback, qos)
        self.camera_info_sub = self.create_subscription(
            CameraInfo, '/camera/camera_info', self.camera_info_callback, qos)
        self.rotate_pub = self.create_publisher(Vector3, '/rotate_command', qos)

        self.fx = None
        self.fy = None
        self.cx = None
        self.cy = None
        self.camera_frame = None

    def camera_info_callback(self, msg: CameraInfo):
        self.fx = msg.k[0]
        self.fy = msg.k[4]
        self.cx = msg.k[2]
        self.cy = msg.k[5]
        self.camera_frame = msg.header.frame_id

    def rotate_callback(self, msg: Detection2D):
        if self.fx is None:
            # Camera intrinsics not received yet — nothing to compute against.
            self.get_logger().warn('No camera info yet — skipping')
            return

        x = msg.bbox.center.position.x
        y = msg.bbox.center.position.y

        # Offset from the principal point (optical axis), in pixels —
        # signed, so direction is preserved.
        offset_x = x - self.cx
        offset_y = y - self.cy

        yaw = math.atan(offset_x / self.fx)
        pitch = math.atan(offset_y / self.fy)

        msg_send = Vector3()
        msg_send.x = 0.0    # roll — not derivable from a single 2D detection
        msg_send.y = pitch
        msg_send.z = yaw
        self.rotate_pub.publish(msg_send)


def main(args=None):
    rclpy.init(args=args)
    node = RotateCommand()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()