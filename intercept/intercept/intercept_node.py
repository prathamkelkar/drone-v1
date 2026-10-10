"""
Intercept node: ArduPilot GUIDED mode through MAVROS. Everything is ENU.

Fully automatic mission, one timer at 'setpoint_rate' (sim time) drives it:

  WAIT_CONNECT  MAVROS connected to the FCU and odometry received
  SET_GUIDED    /mavros/set_mode GUIDED until /mavros/state reports it
  ARM           /mavros/cmd/arming until armed (rejections retried with
                backoff: pre-arm checks / EKF may not be ready yet)
  TAKEOFF       /mavros/cmd/takeoff to 'takeoff_height' (skipped if already
                airborne, e.g. after a manual 'takeoff' in MAVProxy)
  CLIMB         wait until |z - takeoff_height| < 'takeoff_tolerance'
  HOVER         stream the hover setpoint, wait for an intercept target
  TRACK         stream the latest intercept target (held if no new one)
  OVERRIDDEN    mode left GUIDED or disarmed after takeoff: publish nothing,
                once GUIDED+armed again resume HOVER at the current position
                (or TAKEOFF if on the ground)

Each startup step (SET_GUIDED..CLIMB) has a 'step_timeout'; on timeout the
sequence restarts from WAIT_CONNECT (states already satisfied are skipped).

Setpoints: mavros_msgs/PositionTarget on /mavros/setpoint_raw/local, values
in ENU 'map' (MAVROS converts to NED; coordinate_frame is the MAVLink id
FRAME_LOCAL_NED), position + yaw only. They are clamped to a geofence box.
"""
import enum
import math

import rclpy
from rclpy.duration import Duration
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from geometry_msgs.msg import PoseStamped, Vector3
from nav_msgs.msg import Odometry
from mavros_msgs.msg import PositionTarget, State as MavState
from mavros_msgs.srv import CommandBool, CommandTOL, SetMode

from intercept.setpoint_utils import (
    clamp_to_box, is_finite_point, position_type_mask,
    yaw_from_quaternion, yaw_toward_camera_offset,
)


class Phase(enum.Enum):
    WAIT_CONNECT = 'WAIT_CONNECT'
    SET_GUIDED = 'SET_GUIDED'
    ARM = 'ARM'
    TAKEOFF = 'TAKEOFF'
    CLIMB = 'CLIMB'
    HOVER = 'HOVER'
    TRACK = 'TRACK'
    OVERRIDDEN = 'OVERRIDDEN'


STARTUP_PHASES = (Phase.SET_GUIDED, Phase.ARM, Phase.TAKEOFF, Phase.CLIMB)
GUIDED = 'GUIDED'


class OffboardInterceptNode(Node):
    def __init__(self):
        super().__init__('offboard_intercept_node')

        self.declare_parameter('takeoff_height', 4.0)       # m above home (ENU z)
        self.declare_parameter('takeoff_tolerance', 0.3)    # m
        self.declare_parameter('min_target_height', 0.3)    # never dive below this
        self.declare_parameter('airborne_height', 0.5)      # above this, skip takeoff cmd
        self.declare_parameter('setpoint_rate', 20.0)       # Hz (sim time)
        self.declare_parameter('step_timeout', 60.0)        # s (sim) per startup step
        self.declare_parameter('retry_period', 2.0)         # s (sim), first retry delay
        self.declare_parameter('retry_backoff_max', 10.0)   # s (sim), max retry delay
        self.declare_parameter('service_timeout', 5.0)      # s (sim) to wait for a response
        self.declare_parameter('rotate_command_timeout', 1.0)  # s (sim), stale yaw offset -> 0
        # Geofence box for commanded setpoints, ENU 'map' frame (x, y, z).
        self.declare_parameter('fence_min', [-50.0, -50.0, 0.0])
        self.declare_parameter('fence_max', [50.0, 50.0, 20.0])
        self.declare_parameter('odom_topic', '/mavros/local_position/odom')

        gp = self.get_parameter
        self.takeoff_height = float(gp('takeoff_height').value)
        self.takeoff_tolerance = float(gp('takeoff_tolerance').value)
        self.min_target_height = float(gp('min_target_height').value)
        self.airborne_height = float(gp('airborne_height').value)
        self.step_timeout = float(gp('step_timeout').value)
        self.retry_period = float(gp('retry_period').value)
        self.retry_backoff_max = float(gp('retry_backoff_max').value)
        self.service_timeout = float(gp('service_timeout').value)
        self.rotate_timeout = float(gp('rotate_command_timeout').value)
        self.fence_min = [float(v) for v in gp('fence_min').value]
        self.fence_max = [float(v) for v in gp('fence_max').value]
        # min_target_height is the floor for every commanded z.
        self.fence_min[2] = max(self.fence_min[2], self.min_target_height)

        # --- vehicle / mission state -----------------------------------
        self.mav_state = MavState()          # connected=False until MAVROS says otherwise
        self.position = None                 # [x, y, z] ENU map
        self.current_yaw = None              # rad, ENU (CCW from east)
        self.target_position = None          # latest intercept target, ENU
        self.yaw_offset = 0.0                # camera-relative, + = object to the right
        self.yaw_offset_stamp = None
        self.hold = None                     # hover setpoint [x, y, z]

        self.phase = Phase.WAIT_CONNECT
        self.phase_since = self.get_clock().now()
        self.next_attempt = self.phase_since
        self.retry_delay = self.retry_period
        self.pending = None                  # (token, name, start_time) of the in-flight request
        self.token = 0

        # --- ROS interfaces ----------------------------------------------
        best_effort = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )
        # UNVERIFIED: exact QoS MAVROS uses for /mavros/state. Reliable +
        # volatile is compatible with both a volatile and a transient-local
        # reliable publisher; state is re-sent on every FCU heartbeat.
        state_qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )

        self.create_subscription(
            PoseStamped, '/planning/intercept_ellipsoid', self.intercept_callback, best_effort)
        # rotate_command publishes best-effort.
        self.create_subscription(
            Vector3, '/rotate_command', self.rotate_command_callback, best_effort)
        self.create_subscription(
            Odometry, gp('odom_topic').value, self.odom_callback, best_effort)
        self.create_subscription(MavState, '/mavros/state', self.state_callback, state_qos)

        self.setpoint_pub = self.create_publisher(PositionTarget, '/mavros/setpoint_raw/local', 10)

        self.set_mode_client = self.create_client(SetMode, '/mavros/set_mode')
        self.arming_client = self.create_client(CommandBool, '/mavros/cmd/arming')
        self.takeoff_client = self.create_client(CommandTOL, '/mavros/cmd/takeoff')

        self.create_timer(1.0 / float(gp('setpoint_rate').value), self.tick)
        self.get_logger().info(
            f'Intercept node started: takeoff to {self.takeoff_height} m, '
            f'fence {self.fence_min} .. {self.fence_max}')

    # ------------------------------------------------------------------ inputs

    def state_callback(self, msg: MavState):
        prev = self.mav_state
        if (msg.connected, msg.armed, msg.mode) != (prev.connected, prev.armed, prev.mode):
            self.get_logger().info(
                f'FCU: connected={msg.connected} armed={msg.armed} mode={msg.mode}')
        self.mav_state = msg

    def odom_callback(self, msg: Odometry):
        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        self.position = [p.x, p.y, p.z]
        self.current_yaw = yaw_from_quaternion(q.x, q.y, q.z, q.w)

    def intercept_callback(self, msg: PoseStamped):
        p = msg.pose.position
        target = [p.x, p.y, p.z]
        if not is_finite_point(target):
            self.get_logger().warn(f'Ignoring non-finite intercept target {target}')
            return
        # Predictor output is in 'world'; world -> map is identity.
        if msg.header.frame_id not in ('world', 'map', ''):
            self.get_logger().warn(
                f'Ignoring intercept target in unexpected frame "{msg.header.frame_id}"',
                throttle_duration_sec=5.0)
            return
        self.target_position = target

    def rotate_command_callback(self, msg: Vector3):
        # Only yaw (z) is usable: pitch/roll aren't commandable on a quadrotor.
        if math.isfinite(msg.z):
            self.yaw_offset = msg.z
            self.yaw_offset_stamp = self.get_clock().now()

    # ------------------------------------------------------------ state machine

    def _seconds_since(self, t):
        return (self.get_clock().now() - t).nanoseconds * 1e-9

    def _set_phase(self, phase, reason=''):
        if phase == self.phase:
            return
        self.get_logger().info(
            f'{self.phase.value} -> {phase.value}' + (f' ({reason})' if reason else ''))
        self.phase = phase
        self.phase_since = self.get_clock().now()
        self.next_attempt = self.phase_since
        self.retry_delay = self.retry_period
        self.pending = None

    def _backoff(self, why):
        self.get_logger().warn(f'{self.phase.value}: {why}; retrying in {self.retry_delay:.1f} s')
        self.next_attempt = self.get_clock().now() + Duration(seconds=self.retry_delay)
        self.retry_delay = min(self.retry_delay * 2.0, self.retry_backoff_max)

    def _may_attempt(self):
        """True if no request is in flight and the retry delay has passed."""
        if self.pending is not None:
            token, name, started = self.pending
            if self._seconds_since(started) < self.service_timeout:
                return False
            self.pending = None
            self._backoff(f'no response to {name} within {self.service_timeout:.1f} s')
            return False
        return self.get_clock().now() >= self.next_attempt

    def _call(self, client, request, name, on_result):
        if not client.service_is_ready():
            self._backoff(f'service for {name} not available')
            return
        self.token += 1
        token = self.token
        self.pending = (token, name, self.get_clock().now())

        def done(future):
            # Ignore responses to requests we already gave up on.
            if self.pending is None or self.pending[0] != token:
                return
            self.pending = None
            try:
                result = future.result()
            except Exception as e:  # noqa: BLE001 - transport errors are retried
                self._backoff(f'{name} failed: {e}')
                return
            on_result(result)

        client.call_async(request).add_done_callback(done)

    def tick(self):
        ms = self.mav_state
        phase = self.phase

        # Pilot / failsafe took over: stop streaming, don't fight it.
        if phase in (Phase.CLIMB, Phase.HOVER, Phase.TRACK) and (not ms.armed or ms.mode != GUIDED):
            self._set_phase(Phase.OVERRIDDEN, f'armed={ms.armed} mode={ms.mode}')
            self.get_logger().warn('No longer in GUIDED/armed: setpoints stopped')
            return

        if phase in STARTUP_PHASES and self._seconds_since(self.phase_since) > self.step_timeout:
            self.get_logger().error(
                f'{phase.value} timed out after {self.step_timeout:.0f} s, restarting sequence')
            self._set_phase(Phase.WAIT_CONNECT, 'step timeout')
            return

        if phase == Phase.WAIT_CONNECT:
            if ms.connected and self.position is not None:
                self._set_phase(Phase.SET_GUIDED, 'FCU connected, odometry received')
            else:
                self.get_logger().info(
                    f'Waiting for FCU connection ({ms.connected}) and odometry '
                    f'({self.position is not None})', throttle_duration_sec=10.0)

        elif phase == Phase.SET_GUIDED:
            if ms.mode == GUIDED:
                self._set_phase(Phase.ARM, 'mode is GUIDED')
            elif self._may_attempt():
                self._call(self.set_mode_client, SetMode.Request(custom_mode=GUIDED),
                           'set_mode GUIDED', self._on_set_mode)

        elif phase == Phase.ARM:
            if ms.mode != GUIDED:
                self._set_phase(Phase.SET_GUIDED, f'mode changed to {ms.mode}')
            elif ms.armed:
                self._set_phase(Phase.TAKEOFF, 'armed')
            elif self._may_attempt():
                self._call(self.arming_client, CommandBool.Request(value=True),
                           'arming', self._on_arming)

        elif phase == Phase.TAKEOFF:
            if ms.mode != GUIDED:
                self._set_phase(Phase.SET_GUIDED, f'mode changed to {ms.mode}')
            elif not ms.armed:
                self._set_phase(Phase.ARM, 'disarmed before takeoff')
            elif self.position[2] > self.airborne_height:
                self.hold = [self.position[0], self.position[1], self.takeoff_height]
                self._set_phase(Phase.CLIMB, 'already airborne, climbing with setpoints')
            elif self._may_attempt():
                self.hold = [self.position[0], self.position[1], self.takeoff_height]
                req = CommandTOL.Request(min_pitch=0.0, yaw=0.0, latitude=0.0, longitude=0.0,
                                         altitude=float(self.takeoff_height))
                self._call(self.takeoff_client, req, 'takeoff', self._on_takeoff)

        elif phase == Phase.CLIMB:
            if abs(self.position[2] - self.takeoff_height) < self.takeoff_tolerance:
                self._set_phase(Phase.HOVER, f'reached {self.position[2]:.2f} m')
            elif self.position[2] > self.airborne_height:
                # Airborne: stream the hover setpoint. (While still on the
                # ground we leave ArduPilot's takeoff alone.)
                self.publish_setpoint(self.hold)

        elif phase == Phase.HOVER:
            self.publish_setpoint(self.hold)
            if self.target_position is not None:
                self._set_phase(Phase.TRACK, f'target {self._fmt(self.target_position)}')

        elif phase == Phase.TRACK:
            # Latest target; held until a new one arrives.
            self.publish_setpoint(self.target_position)

        elif phase == Phase.OVERRIDDEN:
            if ms.connected and ms.armed and ms.mode == GUIDED and self.position is not None:
                self.target_position = None
                if self.position[2] < self.airborne_height:
                    self._set_phase(Phase.TAKEOFF, 'GUIDED + armed again, on the ground')
                else:
                    self.hold = list(self.position)
                    self._set_phase(Phase.HOVER, 'GUIDED + armed again, holding current position')

    def _on_set_mode(self, res):
        if not res.mode_sent:
            self._backoff('set_mode GUIDED not sent')
        else:
            # Sent is not accepted: wait for /mavros/state before re-sending.
            self.next_attempt = self.get_clock().now() + Duration(
                seconds=self.retry_period)

    def _on_arming(self, res):
        if not res.success:
            self._backoff(f'arming rejected (MAV_RESULT {res.result}; pre-arm checks/EKF not ready?)')
        else:
            self.next_attempt = self.get_clock().now() + Duration(
                seconds=self.retry_period)

    def _on_takeoff(self, res):
        if res.success:
            self._set_phase(Phase.CLIMB, f'takeoff to {self.takeoff_height} m accepted')
        else:
            self._backoff(f'takeoff rejected (MAV_RESULT {res.result})')

    # ---------------------------------------------------------------- output

    @staticmethod
    def _fmt(p):
        return '(' + ', '.join(f'{c:.2f}' for c in p) + ')'

    def _yaw_setpoint(self):
        if self.current_yaw is None:
            return None
        offset = self.yaw_offset
        if (self.yaw_offset_stamp is None
                or self._seconds_since(self.yaw_offset_stamp) > self.rotate_timeout):
            offset = 0.0   # object lost: hold the current heading, don't keep turning
        return yaw_toward_camera_offset(self.current_yaw, offset)

    def publish_setpoint(self, point):
        if point is None or not is_finite_point(point):
            self.get_logger().warn(f'Refusing non-finite setpoint {point}', throttle_duration_sec=2.0)
            return
        sp, clamped = clamp_to_box(point, self.fence_min, self.fence_max)
        if clamped:
            self.get_logger().warn(
                f'Setpoint {self._fmt(point)} clamped to fence -> {self._fmt(sp)}',
                throttle_duration_sec=2.0)

        yaw = self._yaw_setpoint()
        msg = PositionTarget()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'map'
        # MAVROS takes ENU values and converts to NED itself; FRAME_LOCAL_NED
        # is just the MAVLink frame id it expects for local setpoints.
        msg.coordinate_frame = PositionTarget.FRAME_LOCAL_NED
        msg.type_mask = position_type_mask(use_yaw=yaw is not None)
        msg.position.x, msg.position.y, msg.position.z = sp
        msg.yaw = float(yaw) if yaw is not None else 0.0
        self.setpoint_pub.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = OffboardInterceptNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
