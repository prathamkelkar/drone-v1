import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, ReliabilityPolicy, DurabilityPolicy

from geometry_msgs.msg import PoseStamped
from nav_msgs.msg import Odometry

import numpy as np

class Extended_Kalman_Filter(Node):
    def __init__(self):
        super().__init__('extended_kalman_filter')

        self.declare_parameter('gravity', 9.81)
        self.kf = EKF(g=self.get_parameter('gravity').value)

        qos = QoSProfile(
                reliability=ReliabilityPolicy.BEST_EFFORT,
                durability=DurabilityPolicy.VOLATILE,
                history=HistoryPolicy.KEEP_LAST,
                depth=1
            )

        self.initialized = False
        self.last_stamp = None

        self.sub = self.create_subscription(PoseStamped, '/estimation/pose_object_raw', self.pose_callback, qos)
        self.pub = self.create_publisher(Odometry, '/estimation/object_state_', qos)

class EKF():
    def __init__(self, g=9.81, k=0.02):

        self.g = g
        self.k = k
        self.x = np.zeros((6, 1))
        self.P = np.eye(6) * 10
        self.Q = np.diag([0.01, 0.01, 0.01,
                          0.1, 0.1, 0.1])

        self.VZ_THRESHOLD = 0.3
        self.in_flight = False
        self.MIN_SPEED = 1e-6

    def initialize(self, z:np.ndarray):

        self.x[0:3] = z
        self.x[3:6] = 0.0

        self.P = np.diag([0.1, 0.1, 0.1, 100.0, 100.0, 100.0])

    def drag_accel(self, v):

        """a_drag = -k * |v| * v, as a 3x1 vector. v is the 3x1 velocity
        block of the state."""

        speed = np.linalg.norm(v)
        if speed < self.MIN_SPEED:
            return np.zeros((3, 1))

        return -self.k * speed * v

    def _drag_jacobian(self, v):

        """3x3 Jacobian of a_drag w.r.t. v = [vx,vy,vz]. Returns zeros
        if speed is ~0 (drag's effect — and its sensitivity to velocity
        — vanishes at rest)."""

        speed = np.linalg.norm(v)
        if speed < self.MIN_SPEED:
            return np.zeros((3, 3))

        vx, vy, vz = v.flatten()

        J = np.zeros((3, 3))

        # d(a_drag_i)/d(v_j) = -k * ( |v|*delta_ij + v_i*v_j/|v| )
        for i in range(3):
            for j in range(3):
                delta_ij = 1.0 if i == j else 0.0
                J[i, j] = -self.k * (speed * delta_ij + v[i, 0] * v[j, 0] / speed)
        return J

    def predict(self, dt):
        p = self.x[0:3]
        v = self.x[3:6]

        vz = v[2, 0]

        if not self.in_flight and vz > self.VZ_THRESHOLD:
            self.in_flight = True

        g_vec = np.array([[0.0], [0.0] [self.g if self.in_flight else 0.0]])

        a_drag = self.drag_accel(v)



        


