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
  INTERCEPT     hover at home and run intercept attempts (see
                sequencer.InterceptSequencer: READY -> CHASE -> STOP ->
                HOLD -> RETURN -> READY)
  OVERRIDDEN    mode left GUIDED or disarmed after takeoff: publish nothing,
                once GUIDED+armed again resume INTERCEPT at the current
                position (or TAKEOFF if on the ground)

Each startup step (SET_GUIDED..CLIMB) has a 'step_timeout'; on timeout the
sequence restarts from WAIT_CONNECT (states already satisfied are skipped).

How the target is chased ('chase_mode'):
  'thrust' (default)  every cycle, solve the constant acceleration that takes
      the drone from its current position and velocity to the predictor's
      latest point at the point's stamped arrival time
      (thrust_control.timed_intercept_accel), and send it as an
      acceleration-only setpoint; ArduPilot turns it into tilt + thrust.
  'velocity'  full-speed velocity setpoint toward the point plus full
      acceleration feedforward (sequencer.chase_command, brake=False).
In both modes the drone reaches the point at full speed or still
accelerating - it is trying to hit an object there, not stop there.

Setpoints: mavros_msgs/PositionTarget on /mavros/setpoint_raw/local, values
in ENU 'map' (MAVROS converts to NED; coordinate_frame is the MAVLink id
FRAME_LOCAL_NED): position, velocity (+ accel feedforward) or acceleration
only, always with yaw. Position setpoints and targets are clamped to a
geofence box. ArduPilot's own limits (WP_*, PSC_*_JERK, ATC_ANGLE_MAX, see
scripts/intercept.parm) cap what it will actually fly; keep the a_max_* /
v_max_* parameters here at or below them.
"""
import enum
import math

from geometry_msgs.msg import PoseStamped, TwistStamped, Vector3
from intercept.sequencer import chase_command, InterceptSequencer
from intercept.setpoint_utils import (
    accel_type_mask, clamp_to_box, is_finite_point, position_type_mask,
    velocity_type_mask, yaw_from_quaternion, yaw_toward_camera_offset,
)
from intercept.thrust_control import intercept_accel, timed_intercept_accel
from mavros_msgs.msg import PositionTarget, State as MavState
from mavros_msgs.srv import CommandBool, CommandTOL, SetMode
from nav_msgs.msg import Odometry
import numpy as np
import rclpy
from rclpy.duration import Duration
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy


class Phase(enum.Enum):
    WAIT_CONNECT = 'WAIT_CONNECT'
    SET_GUIDED = 'SET_GUIDED'
    ARM = 'ARM'
    TAKEOFF = 'TAKEOFF'
    CLIMB = 'CLIMB'
    INTERCEPT = 'INTERCEPT'
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
        # Hz (sim time). The thrust-mode guidance re-plans every cycle.
        self.declare_parameter('setpoint_rate', 100.0)
        self.declare_parameter('step_timeout', 60.0)        # s (sim) per startup step
        self.declare_parameter('retry_period', 2.0)         # s (sim), first retry delay
        self.declare_parameter('retry_backoff_max', 10.0)   # s (sim), max retry delay
        self.declare_parameter('service_timeout', 5.0)      # s (sim) to wait for a response
        self.declare_parameter('rotate_command_timeout', 1.0)  # s (sim), stale yaw offset -> 0
        # Geofence box for commanded positions, ENU 'map' frame (x, y, z).
        self.declare_parameter('fence_min', [-50.0, -50.0, 0.0])
        self.declare_parameter('fence_max', [50.0, 50.0, 20.0])
        self.declare_parameter('odom_topic', '/mavros/local_position/odom')
        # ENU 'map' velocity (the odometry twist is in the body frame).
        self.declare_parameter('velocity_topic', '/mavros/local_position/velocity_local')

        # How to chase the target ('thrust' or 'velocity', see module docstring).
        # Defaults below are for running the node on its own; the launch
        # file overrides most of them.
        self.declare_parameter('chase_mode', 'thrust')
        self.declare_parameter('v_max_h', 12.0)   # m/s, <= WP_SPD
        self.declare_parameter('v_max_up', 6.0)   # m/s, <= WP_SPD_UP
        self.declare_parameter('v_max_dn', 4.0)   # m/s, <= WP_SPD_DN
        self.declare_parameter('a_brake', 8.0)    # m/s^2 braking after the chase / flying home
        # Acceleration limits: the feedforward magnitudes in velocity mode
        # and the guidance limits in thrust mode. Horizontal: <= WP_ACC in
        # velocity mode, <= g*tan(ATC_ANGLE_MAX) in thrust mode; vertical
        # <= WP_ACC_Z and what the thrust allows.
        self.declare_parameter('a_max_h', 9.8)    # m/s^2
        self.declare_parameter('a_max_up', 4.5)   # m/s^2
        self.declare_parameter('a_max_dn', 5.0)   # m/s^2
        self.declare_parameter('pass_radius', 1.0)  # m, point behind us within this -> passed
        # s, time to tilt from full acceleration to full braking (estimate;
        # raise it if the drone overshoots on the way home)
        self.declare_parameter('response_lag', 0.15)
        # Thrust mode. tilt_delay: planned time before a commanded
        # acceleration takes effect (ArduPilot ramps acceleration at
        # PSC_NE_JERK); must match the predictor's tilt_delay.
        self.declare_parameter('tilt_delay', 0.25)       # s
        self.declare_parameter('min_safe_height', 0.3)   # m, never accelerate down below this
        self.declare_parameter('end_margin', 0.15)       # s to push on after the arrival time
        # s: in the last terminal_time before closest approach, plan with no
        # tilt delay so the push stays at full effort right into the ball
        # (see thrust_control.intercept_accel)
        self.declare_parameter('terminal_time', 0.15)

        # End of an attempt (see InterceptSequencer)
        self.declare_parameter('target_timeout', 0.5)   # s without a new intercept point -> stop
        self.declare_parameter('max_chase_time', 4.0)   # s, longest chase
        self.declare_parameter('max_chase_distance', 6.0)  # m from home, chase limit
        self.declare_parameter('return_speed', 2.0)     # m/s, flight back home
        self.declare_parameter('return_accel', 2.0)     # m/s^2, flight back home
        self.declare_parameter('hold_time', 2.0)        # s to hold after the attempt
        self.declare_parameter('rearm_quiet', 1.0)      # s of no targets before a new attempt

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

        self.chase_mode = gp('chase_mode').value
        if self.chase_mode not in ('thrust', 'velocity'):
            raise ValueError(f"chase_mode must be 'thrust' or 'velocity', not {self.chase_mode!r}")
        self.v_max_h = float(gp('v_max_h').value)
        self.v_max_up = float(gp('v_max_up').value)
        self.v_max_dn = float(gp('v_max_dn').value)
        self.a_brake = float(gp('a_brake').value)
        self.a_max_h = float(gp('a_max_h').value)
        self.a_max_up = float(gp('a_max_up').value)
        self.a_max_dn = float(gp('a_max_dn').value)
        self.response_lag = float(gp('response_lag').value)
        self.tilt_delay = float(gp('tilt_delay').value)
        self.min_safe_height = float(gp('min_safe_height').value)
        self.terminal_time = float(gp('terminal_time').value)
        self.return_speed = float(gp('return_speed').value)
        self.return_accel = float(gp('return_accel').value)

        self.sequencer = InterceptSequencer(
            chase_fn=self._chase,
            return_fn=self._return,
            pass_radius=float(gp('pass_radius').value),
            target_timeout=float(gp('target_timeout').value),
            max_chase_time=float(gp('max_chase_time').value),
            max_chase_distance=float(gp('max_chase_distance').value),
            stop_accel=self.a_brake,
            hold_time=float(gp('hold_time').value),
            rearm_quiet=float(gp('rearm_quiet').value),
            deadline_margin=float(gp('end_margin').value),
            log=lambda m: self.get_logger().info(f'Intercept: {m}'))

        # --- vehicle / mission state -----------------------------------
        self.mav_state = MavState()          # connected=False until MAVROS says otherwise
        self.position = None                 # np [x, y, z] ENU map
        self.velocity = np.zeros(3)          # ENU map
        self.current_yaw = None              # rad, ENU (CCW from east)
        self.yaw_offset = 0.0                # camera-relative, + = object to the right
        self.yaw_offset_stamp = None
        self.home = None                     # hover point [x, y, z]

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
        self.create_subscription(
            TwistStamped, gp('velocity_topic').value, self.velocity_callback, best_effort)
        self.create_subscription(MavState, '/mavros/state', self.state_callback, state_qos)

        self.setpoint_pub = self.create_publisher(PositionTarget, '/mavros/setpoint_raw/local', 10)

        self.set_mode_client = self.create_client(SetMode, '/mavros/set_mode')
        self.arming_client = self.create_client(CommandBool, '/mavros/cmd/arming')
        self.takeoff_client = self.create_client(CommandTOL, '/mavros/cmd/takeoff')

        self.create_timer(1.0 / float(gp('setpoint_rate').value), self.tick)
        self.get_logger().info(
            f'Intercept node started: takeoff to {self.takeoff_height} m, '
            f'chase_mode {self.chase_mode}, fence {self.fence_min} .. {self.fence_max}')

    # ------------------------------------------------------------------ inputs

    def _now(self):
        return self.get_clock().now().nanoseconds * 1e-9

    def state_callback(self, msg: MavState):
        prev = self.mav_state
        if (msg.connected, msg.armed, msg.mode) != (prev.connected, prev.armed, prev.mode):
            self.get_logger().info(
                f'FCU: connected={msg.connected} armed={msg.armed} mode={msg.mode}')
        self.mav_state = msg

    def odom_callback(self, msg: Odometry):
        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        self.position = np.array([p.x, p.y, p.z])
        self.current_yaw = yaw_from_quaternion(q.x, q.y, q.z, q.w)

    def velocity_callback(self, msg: TwistStamped):
        v = msg.twist.linear
        vel = [v.x, v.y, v.z]
        if is_finite_point(vel):
            self.velocity = np.array(vel)

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
        # Fence + floor (min_target_height) apply to the target too.
        target, _ = clamp_to_box(target, self.fence_min, self.fence_max)
        # The predictor stamps the point with the object's predicted arrival time.
        deadline = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9
        # Both chase modes use the predictor's feasible intercept point, never
        # the raw/KF ball stream (that would bypass its feasibility and
        # minimum-height checks).
        self.sequencer.on_target(np.array(target), self._now(), deadline)

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
        """Return True if no request is in flight and the retry delay has passed."""
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
        in_flight_phase = phase in (Phase.CLIMB, Phase.INTERCEPT)
        if in_flight_phase and (not ms.armed or ms.mode != GUIDED):
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
                self.home = [self.position[0], self.position[1], self.takeoff_height]
                self._set_phase(Phase.CLIMB, 'already airborne, climbing with setpoints')
            elif self._may_attempt():
                self.home = [self.position[0], self.position[1], self.takeoff_height]
                req = CommandTOL.Request(min_pitch=0.0, yaw=0.0, latitude=0.0, longitude=0.0,
                                         altitude=float(self.takeoff_height))
                self._call(self.takeoff_client, req, 'takeoff', self._on_takeoff)

        elif phase == Phase.CLIMB:
            if abs(self.position[2] - self.takeoff_height) < self.takeoff_tolerance:
                self.sequencer.reset(self._now(), 'hover height reached')
                self._set_phase(Phase.INTERCEPT, f'reached {self.position[2]:.2f} m')
            elif self.position[2] > self.airborne_height:
                # Airborne: stream the hover setpoint. (While still on the
                # ground we leave ArduPilot's takeoff alone.)
                self.publish_position(self.home)

        elif phase == Phase.INTERCEPT:
            self._intercept_step()

        elif phase == Phase.OVERRIDDEN:
            if ms.connected and ms.armed and ms.mode == GUIDED and self.position is not None:
                if self.position[2] < self.airborne_height:
                    self._set_phase(Phase.TAKEOFF, 'GUIDED + armed again, on the ground')
                else:
                    self.home = list(self.position)
                    self.sequencer.reset(self._now(), 'resumed')
                    self._set_phase(Phase.INTERCEPT,
                                    'GUIDED + armed again, holding current position')

    def _on_set_mode(self, res):
        if not res.mode_sent:
            self._backoff('set_mode GUIDED not sent')
        else:
            # Sent is not accepted: wait for /mavros/state before re-sending.
            self.next_attempt = self.get_clock().now() + Duration(
                seconds=self.retry_period)

    def _on_arming(self, res):
        if not res.success:
            self._backoff(
                f'arming rejected (MAV_RESULT {res.result}; pre-arm checks/EKF not ready?)')
        else:
            self.next_attempt = self.get_clock().now() + Duration(
                seconds=self.retry_period)

    def _on_takeoff(self, res):
        if res.success:
            self._set_phase(Phase.CLIMB, f'takeoff to {self.takeoff_height} m accepted')
        else:
            self._backoff(f'takeoff rejected (MAV_RESULT {res.result})')

    # -------------------------------------------------------------- guidance

    def _chase(self, err, vel):
        if self.chase_mode != 'velocity':      # 'thrust': handled in _intercept_step
            return None, None
        # brake=False: full speed through the point, never slowing before it
        return chase_command(err, vel, self.v_max_h, self.v_max_up, self.v_max_dn,
                             self.a_max_h, self.a_max_up, self.a_max_dn, self.a_brake,
                             self.response_lag, brake=False)

    def _return(self, err, vel):
        # Same braking-curve law as the chase, but slow and gentle so the
        # drone doesn't race home at the full speed limit.
        v_r, a_r = self.return_speed, self.return_accel
        return chase_command(err, vel, v_r, v_r, v_r, a_r, a_r, a_r, a_r, self.response_lag)

    def _thrust_chase(self, now):
        """
        Reach the predictor's latest point at its stamped arrival time.

        The point and absolute deadline are refreshed by
        /planning/intercept_ellipsoid. Every cycle, solve the constant net
        acceleration that takes the drone from its current position and
        velocity to that point in the remaining time, so the drone arrives
        when the object does instead of merely as soon as possible.

        Returns an ENU acceleration setpoint, or None if there is no planned
        point yet.
        """
        target = self.sequencer.target
        deadline = self.sequencer.target_deadline
        if target is None or deadline is None:
            return None

        t_go = deadline - now
        if t_go > 0.0:
            a, _ = timed_intercept_accel(
                self.position, self.velocity, target, t_go,
                self.a_max_h, self.a_max_up, self.a_max_dn,
                delay=self.tilt_delay)
        else:
            # The predicted meeting instant has just passed. Keep pushing
            # through the point during the sequencer's short deadline margin
            # instead of producing a singular timed command or braking early.
            a, _, _ = intercept_accel(
                self.position, self.velocity, target, np.zeros(3), 0.0,
                self.a_max_h, self.a_max_up, self.a_max_dn,
                delay=0.0, terminal_time=self.terminal_time)

        # Ground safety: no downward acceleration close to the ground (ENU z up)
        if self.position[2] < self.min_safe_height:
            a[2] = max(a[2], 2.0)
        return a

    def _intercept_step(self):
        now = self._now()
        home = np.array(self.home)
        state, kind, vec, acc = self.sequencer.step(now, self.position, self.velocity, home)
        if state == 'CHASE' and self.chase_mode == 'thrust':
            a = self._thrust_chase(now)
            if a is None:                   # no planned point available yet
                self.publish_position(home)
            else:
                self.publish_accel(a)
        elif kind == 'velocity' and vec is not None:
            self.publish_velocity(vec, acc)
        else:
            self.publish_position(vec)

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

    def _setpoint_msg(self, type_mask_fn):
        yaw = self._yaw_setpoint()
        msg = PositionTarget()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'map'
        # MAVROS takes ENU values and converts to NED itself; FRAME_LOCAL_NED
        # is just the MAVLink frame id it expects for local setpoints.
        msg.coordinate_frame = PositionTarget.FRAME_LOCAL_NED
        msg.type_mask = type_mask_fn(yaw is not None)
        msg.yaw = float(yaw) if yaw is not None else 0.0
        return msg

    def publish_position(self, point):
        if point is None or not is_finite_point(point):
            self.get_logger().warn(f'Refusing non-finite setpoint {point}',
                                   throttle_duration_sec=2.0)
            return
        sp, clamped = clamp_to_box(point, self.fence_min, self.fence_max)
        if clamped:
            self.get_logger().warn(
                f'Setpoint {self._fmt(point)} clamped to fence -> {self._fmt(sp)}',
                throttle_duration_sec=2.0)
        msg = self._setpoint_msg(position_type_mask)
        msg.position.x, msg.position.y, msg.position.z = sp
        self.setpoint_pub.publish(msg)

    def publish_velocity(self, vel, accel_ff=None):
        """Velocity setpoint, with acceleration feedforward if given."""
        if not is_finite_point(vel):
            self.get_logger().warn(f'Refusing non-finite velocity {vel}',
                                   throttle_duration_sec=2.0)
            return
        use_accel = accel_ff is not None and is_finite_point(accel_ff)
        msg = self._setpoint_msg(lambda use_yaw: velocity_type_mask(use_accel, use_yaw))
        msg.velocity.x, msg.velocity.y, msg.velocity.z = (float(v) for v in vel)
        if use_accel:
            msg.acceleration_or_force.x, msg.acceleration_or_force.y, \
                msg.acceleration_or_force.z = (float(a) for a in accel_ff)
        self.setpoint_pub.publish(msg)

    def publish_accel(self, accel):
        if not is_finite_point(accel):
            self.get_logger().warn(f'Refusing non-finite acceleration {accel}',
                                   throttle_duration_sec=2.0)
            return
        msg = self._setpoint_msg(accel_type_mask)
        msg.acceleration_or_force.x, msg.acceleration_or_force.y, \
            msg.acceleration_or_force.z = (float(a) for a in accel)
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
