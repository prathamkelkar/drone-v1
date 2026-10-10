#!/usr/bin/env python3
"""
One-shot MAVROS configuration helper.

Waits for MAVROS (and the FCU behind it) to come up, then:
  1. sets /mavros/local_position 'tf.send' to false, so odom_to_tf is the only
     publisher of map -> base_link;
  2. requests MAVLink message intervals (ATTITUDE=30, ATTITUDE_QUATERNION=31,
     LOCAL_POSITION_NED=32 by default) at 'message_rate' Hz. Without this,
     ArduPilot SITL streams odometry at only ~2.7 Hz.

Every step is retried until it succeeds or 'timeout' (wall seconds) runs out,
then the node exits. This replaces fixed-delay 'ros2 param set' /
'ros2 service call' processes, which fail if MAVROS is not up yet.

Parameter name 'tf.send' is taken from MAVROS's own apm_config.yaml
(/opt/ros/jazzy/share/mavros/launch/apm_config.yaml, section local_position).
"""
import sys

import rclpy
from rclpy.node import Node
from rclpy.parameter import Parameter
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from rcl_interfaces.srv import SetParameters
from mavros_msgs.msg import State
from mavros_msgs.srv import MessageInterval


class MavrosSetup(Node):
    def __init__(self):
        super().__init__('mavros_setup')

        self.declare_parameter('mavros_ns', '/mavros')
        self.declare_parameter('message_ids', [30, 31, 32])
        self.declare_parameter('message_rate', 30.0)
        self.declare_parameter('disable_mavros_tf', True)
        self.declare_parameter('retry_period', 2.0)   # wall seconds
        self.declare_parameter('timeout', 300.0)      # wall seconds, <= 0 = forever

        ns = self.get_parameter('mavros_ns').value.rstrip('/')
        self.message_rate = float(self.get_parameter('message_rate').value)
        self.timeout = float(self.get_parameter('timeout').value)

        # Pending work. Each entry is removed once MAVROS confirms success.
        self.pending_intervals = set(int(i) for i in self.get_parameter('message_ids').value)
        self.tf_pending = bool(self.get_parameter('disable_mavros_tf').value)
        self.in_flight = set()   # keys of requests waiting for a response

        self.connected = False
        self.finished = False
        self.failed = False

        self.param_client = self.create_client(
            SetParameters, f'{ns}/local_position/set_parameters')
        self.interval_client = self.create_client(
            MessageInterval, f'{ns}/set_message_interval')

        # Reliable + volatile is compatible with both volatile and
        # transient-local reliable publishers. /mavros/state is re-sent on
        # every FCU heartbeat (~1 Hz), so no latching is needed.
        state_qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )
        self.create_subscription(State, f'{ns}/state', self.state_callback, state_qos)

        self.start_time = self.get_clock().now()
        self.create_timer(float(self.get_parameter('retry_period').value), self.tick)
        self.get_logger().info(
            f'Waiting for MAVROS at {ns} (tf.send=false: {self.tf_pending}, '
            f'message ids {sorted(self.pending_intervals)} @ {self.message_rate} Hz)')

    def state_callback(self, msg: State):
        if msg.connected and not self.connected:
            self.get_logger().info('FCU connected')
        self.connected = msg.connected

    def tick(self):
        if self.finished:
            return

        if not self.tf_pending and not self.pending_intervals:
            self.get_logger().info('MAVROS setup complete')
            self.finished = True
            return

        elapsed = (self.get_clock().now() - self.start_time).nanoseconds * 1e-9
        if self.timeout > 0.0 and elapsed > self.timeout:
            what = []
            if self.tf_pending:
                what.append('tf.send=false')
            what += [f'message interval {i}' for i in sorted(self.pending_intervals)]
            self.get_logger().error(
                f'Gave up after {elapsed:.0f} s, still pending: {", ".join(what)}')
            self.failed = True
            self.finished = True
            return

        # 1. tf.send (only needs the MAVROS node, not the FCU)
        if self.tf_pending and 'tf' not in self.in_flight:
            if self.param_client.service_is_ready():
                req = SetParameters.Request()
                req.parameters = [Parameter('tf.send', Parameter.Type.BOOL, False).to_parameter_msg()]
                self.in_flight.add('tf')
                self.param_client.call_async(req).add_done_callback(self.on_tf_done)
            else:
                self.get_logger().info('Waiting for local_position parameter service...',
                                       throttle_duration_sec=10.0)

        # 2. message intervals (need the FCU to be connected to be acked)
        if self.pending_intervals:
            if not self.interval_client.service_is_ready():
                self.get_logger().info('Waiting for set_message_interval service...',
                                       throttle_duration_sec=10.0)
            elif not self.connected:
                self.get_logger().info('Waiting for FCU connection...',
                                       throttle_duration_sec=10.0)
            else:
                for msg_id in sorted(self.pending_intervals):
                    if msg_id in self.in_flight:
                        continue
                    req = MessageInterval.Request()
                    req.message_id = msg_id
                    req.message_rate = self.message_rate
                    self.in_flight.add(msg_id)
                    self.interval_client.call_async(req).add_done_callback(
                        lambda fut, i=msg_id: self.on_interval_done(fut, i))

    def on_tf_done(self, future):
        self.in_flight.discard('tf')
        try:
            result = future.result().results[0]
        except Exception as e:  # noqa: BLE001 - log any transport error and retry
            self.get_logger().warn(f'tf.send request failed: {e}; retrying')
            return
        if result.successful:
            self.tf_pending = False
            self.get_logger().info('Set /mavros/local_position tf.send = false')
        else:
            self.get_logger().warn(f'tf.send rejected: "{result.reason}"; retrying')

    def on_interval_done(self, future, msg_id):
        self.in_flight.discard(msg_id)
        try:
            ok = future.result().success
        except Exception as e:  # noqa: BLE001
            self.get_logger().warn(f'Message interval {msg_id} failed: {e}; retrying')
            return
        if ok:
            self.pending_intervals.discard(msg_id)
            self.get_logger().info(f'Message {msg_id} interval set to {self.message_rate} Hz')
        else:
            self.get_logger().warn(f'FCU rejected message interval {msg_id}; retrying')


def main(args=None):
    rclpy.init(args=args)
    node = MavrosSetup()
    try:
        while rclpy.ok() and not node.finished:
            rclpy.spin_once(node, timeout_sec=0.5)
    except KeyboardInterrupt:
        pass
    failed = node.failed
    node.destroy_node()
    if rclpy.ok():
        rclpy.shutdown()
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
