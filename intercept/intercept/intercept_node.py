import numpy as np
from scipy.spatial.transform import Rotation

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from geometry_msgs.msg import PoseStamped, Vector3
from px4_msgs.msg import (
    OffboardControlMode,
    TrajectorySetpoint,
    VehicleAttitude,
    VehicleCommand
)

class OffboardInterceptNode(Node):
    def __init__(self):
        super().__init__('offboard_intercept_node')

        qos = QoSProfile(
                reliability=ReliabilityPolicy.BEST_EFFORT,
                durability=DurabilityPolicy.VOLATILE,
                history=HistoryPolicy.KEEP_LAST,
                depth=1,
            )

        self.current_yaw = None
        self.target_position = None
        self.yaw_offset = 0.0

        self.intercept_sub = self.create_subscription(
            PoseStamped, '/planning/intercept_ellipsoid', self.intercept_callback, qos)
        self.rotate_cmd_sub = self.create_subscription(
            Vector3, '/rotate_command', self.rotate_command_callback, 10)

        self.attitude_sub = self.create_subscription(
            VehicleAttitude, '/fmu/out/vehicle_attitude', self.attitude_callback, qos)

        self.offboard_mode_pub = self.create_publisher(OffboardControlMode, '/fmu/in/offboard_control_mode', qos)
        self.trajectory_pub = self.create_publisher(TrajectorySetpoint, '/fmu/in/trajectory_setpoint', qos)
        self.vehicle_command_pub = self.create_publisher(VehicleCommand, '/fmu/in/vehicle_command', qos)

        # PX4 needs a steady stream of setpoints flowing for a short
        # while before it will accept an offboard mode switch/arm
        # request — count cycles rather than using a wall-clock timer,
        # so this is robust to sim-time speedup/slowdown.
        self.setpoint_counter = 0
        self.arm_after_n_setpoints = 20
        self.armed_and_offboard = False

        # Must publish continuously at >= 2Hz regardless of new data.
        self.timer = self.create_timer(0.05, self.publish_setpoints)

        self.get_logger().info('Offboard intercept node started')

    def publish_vehicle_command(self, command, param1=0.0, param2=0.0):
        msg = VehicleCommand()
        msg.param1 = param1
        msg.param2 = param2
        msg.command = command
        msg.target_system = 1
        msg.target_component = 1
        msg.source_system = 1
        msg.source_component = 1
        msg.from_external = True
        msg.timestamp = int(self.get_clock().now().nanoseconds / 1000)
        self.vehicle_command_pub.publish(msg)

    def arm_and_offboard(self):
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_DO_SET_MODE, param1=1.0, param2=6.0)
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM, param1=1.0)
        self.get_logger().info('Arm + offboard mode requested')

    def intercept_callback(self, msg: PoseStamped):
        self.target_position = np.array([
            msg.pose.position.x,
            msg.pose.position.y,
            msg.pose.position.z,
        ])

    def attitude_callback(self, msg: VehicleAttitude):
        # PX4 VehicleAttitude.q is [w, x, y, z]
        q_scipy = np.array([msg.q[1], msg.q[2], msg.q[3], msg.q[0]])
        self.current_yaw = Rotation.from_quat(q_scipy).as_euler('xyz')[2]

    def rotate_command_callback(self, msg: Vector3):
        # Only yaw (z) is usable here — pitch/roll aren't directly
        # commandable via TrajectorySetpoint on a quadrotor.
        self.yaw_offset = msg.z

    def publish_setpoints(self):
        # Published every cycle, regardless of whether a target exists
        # yet — PX4 requires this heartbeat at >= 2Hz continuously, or
        # it will never accept/maintain offboard mode.
        offboard_msg = OffboardControlMode()
        offboard_msg.position = True
        offboard_msg.velocity = False
        offboard_msg.acceleration = False
        offboard_msg.attitude = False
        offboard_msg.body_rate = False
        offboard_msg.timestamp = int(self.get_clock().now().nanoseconds / 1000)
        self.offboard_mode_pub.publish(offboard_msg)

        if self.target_position is None:
            return

        traj_msg = TrajectorySetpoint()
        traj_msg.position = [
            float(self.target_position[0]),
            float(self.target_position[1]),
            float(self.target_position[2])
        ]
        traj_msg.velocity = [float('nan')] * 3

        if self.current_yaw is not None:
            traj_msg.yaw = float(self.current_yaw + self.yaw_offset)
        else:
            traj_msg.yaw = float('nan')

        traj_msg.timestamp = int(self.get_clock().now().nanoseconds / 1000)
        self.trajectory_pub.publish(traj_msg)

        self.setpoint_counter += 1
        has_target = self.target_position is not None

        if not self.armed_and_offboard and has_target and self.setpoint_counter >= self.arm_after_n_setpoints:
            self.arm_and_offboard()
            self.armed_and_offboard = True


def main(args=None):
    rclpy.init(args=args)
    node = OffboardInterceptNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()