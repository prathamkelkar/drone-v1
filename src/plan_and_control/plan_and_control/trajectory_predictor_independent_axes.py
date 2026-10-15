#!/usr/bin/env python3
"""
trajectory_predictor_independent_axes_node

Alternative intercept solver using INDEPENDENT per-axis acceleration/
velocity limits, rather than the direction-projected ellipsoid model in
trajectory_predictor_node.py.

Per axis, the drone's flight time to close that axis's distance is
computed separately (each axis has its own a_max/v_max). The overall
time-to-reach is taken as the MAX across axes, since the drone hasn't
"arrived" until every axis has completed its required motion.

Subscribes to /estimation/object_state (nav_msgs/Odometry) and the drone
odometry (/mavros/local_position/odom), publishes the computed intercept
point on /plan/intercept_timestamp_independent_axes. All frames are ENU
(z up); world -> map is identity.
"""

import numpy as np
from scipy.optimize import brentq

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, DurabilityPolicy, ReliabilityPolicy
from nav_msgs.msg import Odometry
from geometry_msgs.msg import PoseStamped


class IndependentAxisInterceptSolver:
    """Pure math — no ROS dependencies, easy to unit test standalone."""

    def __init__(self, g=9.81,
                 a_max_x=4.0, a_max_y=4.0, a_max_z=2.0,
                 v_max_x=5.0, v_max_y=5.0, v_max_z=3.0,
                 h_target=0.0):
        self.g = g
        self.a_max = np.array([a_max_x, a_max_y, a_max_z])
        self.v_max = np.array([v_max_x, v_max_y, v_max_z])
        self.h_target = h_target

    def p_object(self, t, p0, v0):
        """Ballistic position at time t, given initial position/velocity."""
        px = p0[0] + v0[0] * t
        py = p0[1] + v0[1] * t
        pz = p0[2] + v0[2] * t - 0.5 * self.g * t**2
        return np.array([px, py, pz])

    def compute_t_ground(self, pz0, vz0):
        """Analytic time the object crosses h_target."""
        a = 0.5 * self.g
        b = -vz0
        c = self.h_target - pz0

        discriminant = b**2 - 4 * a * c
        if discriminant < 0:
            return None

        sqrt_disc = np.sqrt(discriminant)
        t1 = (-b + sqrt_disc) / (2 * a)
        t2 = (-b - sqrt_disc) / (2 * a)

        valid_times = [t for t in (t1, t2) if t > 0]
        if not valid_times:
            return None
        return max(valid_times)

    def axis_flight_time(self, distance, a_max, v_max):
        """Time to cover `distance` along one axis starting from rest,
        accelerating at a_max up to v_max, then cruising."""
        distance = abs(distance)
        d_accel = v_max**2 / (2 * a_max)

        if distance >= d_accel:
            t_accel = v_max / a_max
            d_remaining = distance - d_accel
            t_cruise = d_remaining / v_max
            return t_accel + t_cruise
        else:
            return np.sqrt(2 * distance / a_max)

    def flight_time_independent(self, delta):
        """Per-axis flight time, combined as the max across axes (the
        drone hasn't arrived until every axis finishes independently)."""
        times = [
            self.axis_flight_time(delta[i], self.a_max[i], self.v_max[i])
            for i in range(3)
        ]
        return max(times)

    def g_func(self, t, p0, v0, drone_start):
        """Root-find target: t_drone_needed(t) - t."""
        p_target = self.p_object(t, p0, v0)
        delta = p_target - drone_start
        t_drone = self.flight_time_independent(delta)
        return t_drone - t

    def solve(self, p0, v0, drone_start):
        """Returns (t_star, p_intercept) or (None, None) if no
        feasible intercept exists within the object's flight time."""
        t_ground = self.compute_t_ground(p0[2], v0[2])
        if t_ground is None:
            return None, None

        try:
            t_star = brentq(
                self.g_func, 1e-6, t_ground,
                args=(p0, v0, drone_start)
            )
        except ValueError:
            return None, None

        p_intercept = self.p_object(t_star, p0, v0)
        return t_star, p_intercept


class TrajectoryPredictorIndependentAxesNode(Node):
    def __init__(self):
        super().__init__('trajectory_predictor_independent_axes_node')

        # TODO: replace with real per-axis values from ArduPilot params
        # (WP_ACC, WP_SPD, ...) or empirical testing.
        self.declare_parameter('a_max_x', 4.0)
        self.declare_parameter('a_max_y', 4.0)
        self.declare_parameter('a_max_z', 2.0)
        self.declare_parameter('v_max_x', 5.0)
        self.declare_parameter('v_max_y', 5.0)
        self.declare_parameter('v_max_z', 3.0)
        self.declare_parameter('h_target', 0.0)
        self.declare_parameter('drone_odom_topic', '/mavros/local_position/odom')

        self.solver = IndependentAxisInterceptSolver(
            a_max_x=self.get_parameter('a_max_x').value,
            a_max_y=self.get_parameter('a_max_y').value,
            a_max_z=self.get_parameter('a_max_z').value,
            v_max_x=self.get_parameter('v_max_x').value,
            v_max_y=self.get_parameter('v_max_y').value,
            v_max_z=self.get_parameter('v_max_z').value,
            h_target=self.get_parameter('h_target').value,
        )

        self.drone_position = None

        # Both publishers (object_kalman_filter, MAVROS) are best-effort.
        best_effort = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT,
                                 durability=DurabilityPolicy.VOLATILE,
                                 history=HistoryPolicy.KEEP_LAST,
                                 depth=10)
        self.object_state_sub = self.create_subscription(
            Odometry, '/estimation/object_state', self.object_state_callback, best_effort)

        self.drone_odom_sub = self.create_subscription(
            Odometry, self.get_parameter('drone_odom_topic').value,
            self.drone_odom_callback, best_effort)

        self.intercept_pub = self.create_publisher(
            PoseStamped, '/plan/intercept_timestamp_independent_axes', 10)

        self.get_logger().info('trajectory_predictor_independent_axes_node started')

    def drone_odom_callback(self, msg: Odometry):
        self.drone_position = np.array([
            msg.pose.pose.position.x,
            msg.pose.pose.position.y,
            msg.pose.pose.position.z,
        ])

    def object_state_callback(self, msg: Odometry):
        if self.drone_position is None:
            self.get_logger().warn('No drone position yet — skipping solve')
            return

        p0 = np.array([
            msg.pose.pose.position.x,
            msg.pose.pose.position.y,
            msg.pose.pose.position.z,
        ])
        v0 = np.array([
            msg.twist.twist.linear.x,
            msg.twist.twist.linear.y,
            msg.twist.twist.linear.z,
        ])

        t_star, p_intercept = self.solver.solve(p0, v0, self.drone_position)

        if t_star is None:
            self.get_logger().warn('No feasible intercept found')
            return

        self.get_logger().info(
            f'[independent-axes] Intercept in {t_star:.2f}s at {p_intercept}'
        )

        out = PoseStamped()
        out.header = msg.header
        out.pose.position.x = float(p_intercept[0])
        out.pose.position.y = float(p_intercept[1])
        out.pose.position.z = float(p_intercept[2])
        out.pose.orientation.w = 1.0
        self.intercept_pub.publish(out)


def main(args=None):
    rclpy.init(args=args)
    node = TrajectoryPredictorIndependentAxesNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()