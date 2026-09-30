import rclpy
from rclpy.node import Node
from nav_msgs.msg import Odometry
from geometry_msgs.msg import PoseStamped

from scipy.optimize import brentq
import numpy as np

class Intercept_Solver:
    def __init__(self, g=9.81, a_max_h=4.0, a_max_v=2.0, v_max=5.0, h_target=0.0):
        self.g = g
        self.a_max_h = a_max_h
        self.a_max_v = a_max_v
        self.v_max = v_max
        self.h_target = h_target

    def p_object(self, t, p0, v0):

        """Ballistic position at time t, given initial position/velocity."""

        px = p0[0] + v0[0] * t
        py = p0[1] + v0[1] * t
        pz = p0[2] + v0[2] * t - 0.5 * self.g * t ** 2
        return np.array([px, py, pz])

    def compute_t_ground(self, pz0, vz0):

        """Analytic time the object crosses h_target, solving the
        ballistic quadratic directly. Returns the smallest positive
        future root, or None if the object never reaches h_target."""

        a = 0.5 * self.g
        b = -vz0
        c = self.target - pz0

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

    def effective_accel(self, direction_unit_vector):

        """Direction-projected acceleration limit, via an ellipsoidal
        constraint fusing separate horizontal/vertical capability.
        Provably never exceeds a_max_h or a_max_v on any axis."""

        dx, dy, dz = direction_unit_vector
        denom = (dx / self.a_max_h)**2 + (dy / self.a_max_h)**2 + (dz / self.a_max_v)**2
        if denom < 1e-12:
            return self.a_max_h
        return 1.0 / np.sqrt(denom)

    def flight_time(self, distance, a_eff):

        """Time for the drone to cover `distance` starting from rest,
        accelerating at a_eff up to v_max, then cruising."""

        d_accel = self.v_max ** 2 / (2 * a_eff)

        if distance >= d_accel:
            t_accel = self.v_max / a_eff
            d_remaining = distance - d_accel
            t_cruise = d_remaining/self.v_max
            return t_accel + t_cruise
        else:
            return np.sqrt(distance * 2 / a_eff)

    def g_func(self, t, p0, v0, drone_start):
        """Root-find target: t_drone_needed(t) - t. Zero at the
        self-consistent intercept time."""

        p_target = self.p_object(t, p0, v0)
        delta = p_target - drone_start
        dist = np.linalg.norm(delta)

        if dist < 1e-9:
            direction = np.array([0.0, 0.0, 1.0])
        else:
            direction = delta/dist

        a_eff = self.effective_accel(direction)
        t_drone = self.flight_time(dist, a_eff)

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
            # g_func doesn't change sign across the bracket — no
            # feasible intercept with current drone capability.
            return None, None

        p_intercept = self.p_object(t_star, p0, v0)
        return t_star, p_intercept

class TrajectoryPredictionNode(Node):

    def __init__(self):

        super().__init__('trajectory_predictor_ellipsoid')
        self.declare_parameter('a_max_h', 4.0)
        self.declare_parameter('a_max_v', 2.0)
        self.declare_parameter('v_max', 5.0)
        self.declare_parameter('h_target', 0.0)
 
        self.solver = Intercept_Solver(
            a_max_h=self.get_parameter('a_max_h').value,
            a_max_v=self.get_parameter('a_max_v').value,
            v_max=self.get_parameter('v_max').value,
            h_target=self.get_parameter('h_target').value,
        )
 
        self.drone_position = None
 
        self.object_state_sub = self.create_subscription(
            Odometry, '/state_estimation/object_state', self.object_state_callback, 10)

        self.drone_odom_sub = self.create_subscription(
            Odometry, '/fmu/out/vehicle_odometry', self.drone_odom_callback, 10)
 
        self.intercept_pub = self.create_publisher(
            PoseStamped, '/plan/intercept_timestamp_ellipsoid', 10)
 
        self.get_logger().info('trajectory_predictor_node started')

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
            f'Intercept in {t_star:.2f}s at {p_intercept}'
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
    node = TrajectoryPredictionNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()
 
 
if __name__ == '__main__':
    main()

    

    
