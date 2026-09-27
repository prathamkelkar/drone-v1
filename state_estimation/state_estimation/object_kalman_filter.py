import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from geometry_msgs.msg import PoseStamped
from nav_msgs.msg import Odometry

import numpy as np


class Object_Kalman_Filter(Node):
    def __init__(self):
        super().__init__('object_kalman_filter')

        self.kf = KalmanFilter()

        qos = QoSProfile(
                reliability=ReliabilityPolicy.BEST_EFFORT,
                durability=DurabilityPolicy.VOLATILE,
                history=HistoryPolicy.KEEP_LAST,
                depth=1
        )

        self.initialized = False
        self.last_stamp = None

        self.sub = self.create_subscription(PoseStamped, '/estimation/pose_object_raw', self.pose_callback, qos)

        self.pub = self.create_publisher(Odometry, '/estimation/object_state', qos)

    def pose_callback(self, msg: PoseStamped):

        z = np.array([
            [msg.pose.position.x],
            [msg.pose.position.y],
            [msg.pose.position.z]
        ])

        stamp = msg.header.stamp

        if not self.initialized:
            self.kf.initialize(z)
            self.last_stamp = stamp
            self.initialized = True
            self.get_logger().info('Kalman filter initialized from first measurement')
            return

        dt = (stamp.sec + stamp.nanosec * 1e-9) - (self.last_stamp.sec + self.last_stamp.nanosec * 1e-9)

        if dt <= 0.0:
            self.get_logger().warn(f'Non-positive dt ({dt:.4f}s) - skipping this update')
            return

        self.kf.predict(dt)
        self.kf.update(z)

        self.last_stamp = stamp

        self.publish_state(msg.header)

    def publish_state(self, header):

        msg_out = Odometry()
        msg_out.header = header
        msg_out.child_frame_id = 'object'

        msg_out.pose.pose.position.x = float(self.kf.x[0, 0])
        msg_out.pose.pose.position.y = float(self.kf.x[1, 0])
        msg_out.pose.pose.position.z = float(self.kf.x[2, 0])
        # Orientation left as identity (0,0,0,1) - not meaningful for a
        # thrown object being tracked as a point mass.
        msg_out.pose.pose.orientation.w = 1.0

        msg_out.twist.twist.linear.x = float(self.kf.x[3, 0])
        msg_out.twist.twist.linear.y = float(self.kf.x[4, 0])
        msg_out.twist.twist.linear.z = float(self.kf.x[5, 0])
        # Angular velocity left as zero - same reasoning as orientation.

        # PoseWithCovariance/TwistWithCovariance each expect a flat 36-element
        # (6x6) array. Position covariance goes in the top-left 3x3 block of
        # pose.covariance; velocity covariance in the top-left 3x3 of
        # twist.covariance. Build both from our 6x6 P.
        pose_cov = np.zeros((6, 6))
        pose_cov[0:3, 0:3] = self.kf.P[0:3, 0:3]
        msg_out.pose.covariance = pose_cov.flatten().tolist()

        twist_cov = np.zeros((6, 6))
        twist_cov[0:3, 0:3] = self.kf.P[3:6, 3:6]
        msg_out.twist.covariance = twist_cov.flatten().tolist()

        self.pub.publish(msg_out)


class KalmanFilter():
    def __init__(self):

        self.g = 9.81
        self.x = np.zeros((6, 1))
        self.P = np.eye(6) * 10
        self.Q = np.diag([0.01, 0.01, 0.01,
                          0.1, 0.1, 0.1])

    def initialize(self, z: np.ndarray):
        self.x[0:3] = z
        self.x[3:6] = 0.0
        self.P = np.eye(6) * 10.0

    def predict(self, dt):

        F = np.array([
            [1, 0, 0, dt, 0,  0 ],
            [0, 1, 0, 0,  dt, 0 ],
            [0, 0, 1, 0,  0,  dt],
            [0, 0, 0, 1,  0,  0 ],
            [0, 0, 0, 0,  1,  0 ],
            [0, 0, 0, 0,  0,  1 ],
        ])

        B = np.array([
            [0],
            [0],
            [-0.5 * dt**2],
            [0],
            [0],
            [-dt],
        ])

        u = self.g

        self.x = F @ self.x + B * u

        self.P = F @ self.P @ F.T + self.Q

    def update(self, z):

        H = np.array([
            [1, 0, 0, 0, 0, 0],
            [0, 1, 0, 0, 0, 0],
            [0, 0, 1, 0, 0, 0],
        ])

        R = np.diag([0.05, 0.05, 0.15])

        y = z - H @ self.x
        S = H @ self.P @ H.T + R

        K = self.P @ H.T @ np.linalg.inv(S)

        self.x = self.x + K @ y
        self.P = (np.eye(6) - K @ H) @ self.P


def main(args=None):
    rclpy.init(args=args)
    node = Object_Kalman_Filter()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()