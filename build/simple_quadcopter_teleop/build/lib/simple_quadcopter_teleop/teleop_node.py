#!/usr/bin/env python3
"""
Simple keyboard teleop node for PX4 offboard control via px4_msgs.

Controls:
  w/s : forward / backward   (+x / -x body-ish, actually NED world x)
  a/d : left / right         (-y / +y)
  i/k : up / down            (-z / +z, NED so up is negative z)
  j/l : yaw left / right
  arm : press 'r' to arm + switch to offboard
  q   : quit

This publishes velocity setpoints (not position) so it feels like
direct manual control. Uses NED frame internally, matching PX4.
"""

import sys
import termios
import tty
import select

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from px4_msgs.msg import (
    OffboardControlMode,
    TrajectorySetpoint,
    VehicleCommand,
    VehicleStatus,
)


class TeleopNode(Node):
    def __init__(self):
        super().__init__('teleop_node')

        # PX4 requires BEST_EFFORT + VOLATILE QoS for these topics
        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        self.offboard_control_mode_pub = self.create_publisher(
            OffboardControlMode, '/fmu/in/offboard_control_mode', qos)
        self.trajectory_setpoint_pub = self.create_publisher(
            TrajectorySetpoint, '/fmu/in/trajectory_setpoint', qos)
        self.vehicle_command_pub = self.create_publisher(
            VehicleCommand, '/fmu/in/vehicle_command', qos)

        self.status_sub = self.create_subscription(
            VehicleStatus, '/fmu/out/vehicle_status_v1', self.status_callback, qos)

        # current commanded velocity (NED, m/s) and yaw rate (rad/s)
        self.vx = 0.0
        self.vy = 0.0
        self.vz = 0.0
        self.yaw_rate = 0.0

        self.speed = 1.0        # m/s per key press
        self.yaw_speed = 0.5    # rad/s per key press

        self.armed = False
        self.offboard_requested = False
        self.nav_state = None

        # main loop timer — must publish at >= 2Hz, we do 20Hz
        self.timer = self.create_timer(0.05, self.timer_callback)

        # counter so we send offboard mode msgs a bit before arming
        self.setpoint_counter = 0

        self.get_logger().info(
            "Teleop ready. w/a/s/d = move, i/k = up/down, j/l = yaw, "
            "r = arm+offboard, q = quit"
        )

    def status_callback(self, msg):
        self.armed = (msg.arming_state == VehicleStatus.ARMING_STATE_ARMED)
        self.nav_state = msg.nav_state

    def publish_offboard_control_mode(self):
        msg = OffboardControlMode()
        msg.position = False
        msg.velocity = True
        msg.acceleration = False
        msg.attitude = False
        msg.body_rate = False
        msg.timestamp = int(self.get_clock().now().nanoseconds / 1000)
        self.offboard_control_mode_pub.publish(msg)

    def publish_trajectory_setpoint(self):
        msg = TrajectorySetpoint()
        msg.position = [float('nan'), float('nan'), float('nan')]
        msg.velocity = [self.vx, self.vy, self.vz]
        msg.yaw = float('nan')
        msg.yawspeed = self.yaw_rate
        msg.timestamp = int(self.get_clock().now().nanoseconds / 1000)
        self.trajectory_setpoint_pub.publish(msg)

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
        # Switch to offboard mode
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_DO_SET_MODE, param1=1.0, param2=6.0)
        # Arm
        self.publish_vehicle_command(
            VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM, param1=1.0)
        self.get_logger().info("Arm + offboard mode requested")

    def timer_callback(self):
        # Always publish offboard heartbeat + setpoint, required continuously
        self.publish_offboard_control_mode()
        self.publish_trajectory_setpoint()

        key = self.get_key()
        if key is None:
            return

        if key == 'w':
            self.vx = self.speed
        elif key == 's':
            self.vx = -self.speed
        elif key == 'a':
            self.vy = -self.speed
        elif key == 'd':
            self.vy = self.speed
        elif key == 'i':
            self.vz = -self.speed   # NED: negative z = up
        elif key == 'k':
            self.vz = self.speed
        elif key == 'j':
            self.yaw_rate = -self.yaw_speed
        elif key == 'l':
            self.yaw_rate = self.yaw_speed
        elif key == ' ':
            # space = stop / zero velocity
            self.vx = self.vy = self.vz = 0.0
            self.yaw_rate = 0.0
        elif key == 'r':
            # need a stream of setpoints flowing before PX4 accepts offboard,
            # so only call this after teleop's been running a bit
            self.arm_and_offboard()
        elif key == 'q':
            self.get_logger().info("Quitting")
            rclpy.shutdown()

    def get_key(self):
        # non-blocking single keypress read from stdin
        dr, _, _ = select.select([sys.stdin], [], [], 0)
        if dr:
            return sys.stdin.read(1)
        return None


def main(args=None):
    settings = termios.tcgetattr(sys.stdin)
    tty.setcbreak(sys.stdin.fileno())

    rclpy.init(args=args)
    node = TeleopNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, settings)


if __name__ == '__main__':
    main()