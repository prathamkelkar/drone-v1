#!/usr/bin/env python3
"""
trajectory_predictor_node

Subscribes to the object's filtered state (/estimation/object_state,
nav_msgs/Odometry from object_kalman_filter_node) and the drone's own
current position (/fmu/out/vehicle_odometry or equivalent), and solves
for a one-shot straight-line intercept point + time.

Re-solves on every new object state update rather than committing once,
so the plan self-corrects as the KF estimate refines and as the drone
moves.

Model:
- Object: known ballistic trajectory (gravity-only, no drag)
- Drone: straight-line flight toward the intercept point, with
  direction-dependent effective acceleration AND velocity limits,
  each derived from separate horizontal/vertical capabilities via an
  ellipsoid projection (a real quadrotor's vertical and horizontal max
  acceleration AND max cruise speed both generally differ).
- Solve: brentq root-find on g(t) = t_drone_needed(t) - t, bracketed by
  [0, t_ground], where t_ground is the analytic time the object reaches
  the intercept height.

An independent-axes comparison model is also included (see
flight_time_independent_axes / solve_independent_axes) purely for
side-by-side comparison logging — NOT used for the actual published
command by default, since it implies a staggered, non-straight-line
path that doesn't match a quadrotor's shared-thrust-vector actuation.
"""

import numpy as np
from scipy.optimize import brentq

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, DurabilityPolicy, ReliabilityPolicy
from nav_msgs.msg import Odometry
from geometry_msgs.msg import PoseStamped
from px4_msgs.msg import VehicleOdometry


class InterceptSolver:
    """Pure math — no ROS dependencies, easy to unit test standalone."""

    def __init__(self, g=9.81,
                 a_max_h=5.0, a_max_v=2.0,
                 v_max_h=20.0, v_max_v=3.0,
                 h_target=0.0, max_time=5.0):
        self.g = g
        # Search horizon (s) when the object never lands (g == 0, i.e. a
        # constant-velocity object); with gravity the horizon is t_ground.
        self.max_time = max_time
        self.a_max_h = a_max_h   # max horizontal acceleration, m/s^2
        self.a_max_v = a_max_v   # max vertical acceleration, m/s^2
        self.v_max_h = v_max_h   # max horizontal cruise speed, m/s
        self.v_max_v = v_max_v   # max vertical cruise speed, m/s
        self.h_target = h_target  # intercept height (0 = ground)

    def p_object(self, t, p0, v0):
        """Ballistic position at time t, given initial position/velocity."""
        px = p0[0] + v0[0] * t
        py = p0[1] + v0[1] * t
        pz = p0[2] + v0[2] * t - 0.5 * self.g * t**2
        return np.array([px, py, pz])

    def time_horizon(self, pz0, vz0):
        """Upper bound of the intercept search: the landing time for a
        ballistic object, or a fixed horizon for a constant-velocity one."""
        if self.g == 0.0:
            return self.max_time
        return self.compute_t_ground(pz0, vz0)

    def compute_t_ground(self, pz0, vz0):
        """Analytic time the object crosses h_target, solving the
        ballistic quadratic directly. Returns the smallest positive
        future root, or None if the object never reaches h_target."""
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

    # --- Ellipsoid (direction-projected) model -------------------------

    def _ellipsoid_project(self, direction_unit_vector, limit_h, limit_v):
        """Shared projection logic: find the scalar magnitude, along
        direction_unit_vector, at which the ellipsoid
        (dx/limit_h)^2 + (dy/limit_h)^2 + (dz/limit_v)^2 = 1
        is satisfied. Used identically for both acceleration and
        velocity limits — same derivation, different limit pair."""
        dx, dy, dz = direction_unit_vector
        denom = (dx / limit_h)**2 + (dy / limit_h)**2 + (dz / limit_v)**2
        if denom < 1e-12:
            return limit_h  # degenerate zero-direction case, shouldn't occur
        return 1.0 / np.sqrt(denom)

    def effective_accel(self, direction_unit_vector):
        """Direction-projected acceleration limit. Provably never
        exceeds a_max_h or a_max_v on any axis component."""
        return self._ellipsoid_project(direction_unit_vector, self.a_max_h, self.a_max_v)

    def effective_velocity(self, direction_unit_vector):
        """Direction-projected cruise speed limit. Same ellipsoid
        projection as effective_accel but for velocity — provably
        never exceeds v_max_h or v_max_v on any axis component."""
        return self._ellipsoid_project(direction_unit_vector, self.v_max_h, self.v_max_v)

    def flight_time(self, distance, a_eff, v_eff):
        """Time for the drone to cover `distance` starting from rest,
        accelerating at a_eff up to v_eff, then cruising."""
        d_accel = v_eff**2 / (2 * a_eff)

        if distance >= d_accel:
            t_accel = v_eff / a_eff
            d_remaining = distance - d_accel
            t_cruise = d_remaining / v_eff
            return t_accel + t_cruise
        else:
            return np.sqrt(2 * distance / a_eff)

    def g_func(self, t, p0, v0, drone_start):
        """Root-find target: t_drone_needed(t) - t. Zero at the
        self-consistent intercept time."""
        p_target = self.p_object(t, p0, v0)
        delta = p_target - drone_start
        dist = np.linalg.norm(delta)

        if dist < 1e-9:
            direction = np.array([0.0, 0.0, 1.0])
        else:
            direction = delta / dist

        a_eff = self.effective_accel(direction)
        v_eff = self.effective_velocity(direction)
        t_drone = self.flight_time(dist, a_eff, v_eff)

        return t_drone - t

    def _earliest_root(self, g, t_end, args, samples=200):
        """Earliest t in (0, t_end] with g(t) <= 0, i.e. the first moment the
        drone can be where the object is. g is sampled on a grid first:
        bracketing only the two ends of the window misses intercepts that are
        feasible in the middle but not at the end (e.g. a falling object that
        the drone can reach early on but not once it has dropped further)."""
        ts = np.linspace(1e-6, t_end, samples)
        prev_t, prev_g = ts[0], g(ts[0], *args)
        if prev_g <= 0.0:
            return prev_t
        for t in ts[1:]:
            gt = g(t, *args)
            if gt <= 0.0:
                return brentq(g, prev_t, t, args=args)
            prev_t, prev_g = t, gt
        return None

    def solve(self, p0, v0, drone_start):
        """Returns (t_star, p_intercept) for the earliest feasible intercept,
        or (None, None) if none exists within the object's flight time."""
        t_ground = self.time_horizon(p0[2], v0[2])
        if t_ground is None:
            return None, None
        t_star = self._earliest_root(self.g_func, t_ground, (p0, v0, drone_start))
        if t_star is None:
            return None, None
        return t_star, self.p_object(t_star, p0, v0)

    # --- Independent-axes comparison model ------------------------------
    # NOTE: does NOT correspond to a straight-line path — axes that
    # finish early are assumed to simply wait, producing a staggered
    # path. Kept here purely for side-by-side comparison logging
    # against the ellipsoid model, not as the primary/published model.

    def flight_time_independent_axes(self, delta):
        times = []
        for i in range(3):
            d = abs(delta[i])
            a_axis = self.a_max_v if i == 2 else self.a_max_h
            v_axis = self.v_max_v if i == 2 else self.v_max_h
            times.append(self.flight_time(d, a_axis, v_axis))
        return max(times)

    def g_func_independent_axes(self, t, p0, v0, drone_start):
        p_target = self.p_object(t, p0, v0)
        delta = p_target - drone_start
        t_drone = self.flight_time_independent_axes(delta)
        return t_drone - t

    def solve_independent_axes(self, p0, v0, drone_start):
        t_ground = self.time_horizon(p0[2], v0[2])
        if t_ground is None:
            return None, None
        t_star = self._earliest_root(self.g_func_independent_axes, t_ground,
                                     (p0, v0, drone_start))
        if t_star is None:
            return None, None
        return t_star, self.p_object(t_star, p0, v0)


class TrajectoryPredictorNode(Node):
    def __init__(self):
        super().__init__('trajectory_predictor_node')

        # TODO: replace with real values from PX4 params
        # (MPC_ACC_HOR_MAX, MPC_ACC_UP_MAX/MPC_ACC_DOWN_MAX,
        # MPC_XY_VEL_MAX, MPC_Z_VEL_MAX_UP/DN) or empirical
        # step-response testing in Gazebo.
        self.declare_parameter('a_max_h', 5.0)
        self.declare_parameter('a_max_v', 5.0)
        self.declare_parameter('v_max_h', 20.0)
        self.declare_parameter('v_max_v', 3.0)
        self.declare_parameter('h_target', 0.0)
        self.declare_parameter('intercept_mode', 'ellipsoid')  # 'ellipsoid' or 'independent_axes'
        # How the object moves: 'ballistic' (gravity only, thrown/dropped),
        # 'constant_velocity' (no gravity, e.g. a ball gliding sideways) or
        # 'static' (just fly to where it is now).
        self.declare_parameter('object_model', 'ballistic')

        self.solver = InterceptSolver(
            a_max_h=self.get_parameter('a_max_h').value,
            a_max_v=self.get_parameter('a_max_v').value,
            v_max_h=self.get_parameter('v_max_h').value,
            v_max_v=self.get_parameter('v_max_v').value,
            h_target=self.get_parameter('h_target').value,
        )

        # Same drone limits, but g=0 so the object keeps its velocity.
        self.solver_cv = InterceptSolver(
            g=0.0,
            a_max_h=self.get_parameter('a_max_h').value,
            a_max_v=self.get_parameter('a_max_v').value,
            v_max_h=self.get_parameter('v_max_h').value,
            v_max_v=self.get_parameter('v_max_v').value,
            h_target=self.get_parameter('h_target').value,
        )

        self.drone_position = None

        self.object_state_sub = self.create_subscription(
            Odometry, '/estimation/object_state', self.object_state_callback,
            QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT,
                       durability=DurabilityPolicy.VOLATILE,
                       history=HistoryPolicy.KEEP_LAST,
                       depth=10))

        # PX4 publishes best-effort; match px4_odom_to_tf's QoS.
        px4_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1
        )
        self.drone_odom_sub = self.create_subscription(
            VehicleOdometry, '/fmu/out/vehicle_odometry', self.drone_odom_callback, px4_qos)

        self.intercept_pub = self.create_publisher(
            PoseStamped, '/planning/intercept_ellipsoid', 10)

        self.get_logger().info('trajectory_predictor_node started')

    def drone_odom_callback(self, msg: VehicleOdometry):
        # PX4 is NED (z down); the solver works with z up.
        self.drone_position = np.array([
            msg.position[0],
            msg.position[1],
            -msg.position[2],
        ])

    def object_state_callback(self, msg: Odometry):
        if self.drone_position is None:
            self.get_logger().warn('No drone position yet — skipping solve')
            return

        # Object state is in the NED 'world' frame; flip z to z-up.
        p0 = np.array([
            msg.pose.pose.position.x,
            msg.pose.pose.position.y,
            -msg.pose.pose.position.z,
        ])
        v0 = np.array([
            msg.twist.twist.linear.x,
            msg.twist.twist.linear.y,
            -msg.twist.twist.linear.z,
        ])

        model = self.get_parameter('object_model').value
        solver = self.solver_cv if model == 'constant_velocity' else self.solver

        if model == 'static':
            # Stationary object: fly straight to where it is.
            delta = p0 - self.drone_position
            dist = float(np.linalg.norm(delta))
            direction = delta / dist if dist > 1e-9 else np.array([0.0, 0.0, 1.0])
            t_star = solver.flight_time(
                dist,
                solver.effective_accel(direction),
                solver.effective_velocity(direction))
            p_intercept = p0
        else:
            t_star, p_intercept = solver.solve(p0, v0, self.drone_position)

        # Log the independent-axes estimate alongside as a comparison
        # point, without using it for the actual published command.
        t_star_alt, _ = solver.solve_independent_axes(p0, v0, self.drone_position)
        if t_star is not None and t_star_alt is not None:
            self.get_logger().debug(
                f'ellipsoid t*={t_star:.3f}s  independent_axes t*={t_star_alt:.3f}s'
            )

        if self.get_parameter('intercept_mode').value == 'independent_axes':
            t_star, p_intercept = solver.solve_independent_axes(p0, v0, self.drone_position)

        if t_star is None:
            self.get_logger().warn('No feasible intercept found')
            return

        self.get_logger().info(
            f'Intercept in {t_star:.2f}s at {p_intercept}'
        )

        out = PoseStamped()
        out.header = msg.header
        out.pose.position.x = float(p_intercept[0])
        out.pose.position.y = float(p_intercept[1])
        out.pose.position.z = float(-p_intercept[2])  # back to NED (z down)
        out.pose.orientation.w = 1.0
        self.intercept_pub.publish(out)


def main(args=None):
    rclpy.init(args=args)
    node = TrajectoryPredictorNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()