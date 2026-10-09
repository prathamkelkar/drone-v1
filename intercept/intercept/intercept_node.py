import numpy as np
from scipy.spatial.transform import Rotation

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

from geometry_msgs.msg import PoseStamped, Vector3
from nav_msgs.msg import Odometry
from px4_msgs.msg import (
    OffboardControlMode,
    TrajectorySetpoint,
    VehicleAttitude,
    VehicleCommand,
    VehicleOdometry
)

from intercept.thrust_control import ball_position, intercept_accel

def _cap_along(direction, magnitude, lim_h, lim_up, lim_dn):
    """Largest value <= magnitude such that direction * value keeps its
    horizontal part under lim_h and its vertical part under lim_up
    (climbing, -z in NED) or lim_dn (descending)."""
    h = float(np.linalg.norm(direction[:2]))
    if h > 1e-6:
        magnitude = min(magnitude, lim_h / h)
    lim_z = lim_up if direction[2] < 0 else lim_dn
    if abs(direction[2]) > 1e-6:
        magnitude = min(magnitude, lim_z / abs(direction[2]))
    return magnitude


def chase_command(err, vel, v_max_h, v_max_up, v_max_dn,
                  a_max_h, a_max_up, a_max_dn, a_brake, response_lag=0.15, tol=0.3):
    """Velocity setpoint and acceleration feedforward (both NED) to close
    position error `err` as fast as possible, given current velocity `vel`.

    Speed profile along the line to the target:
      v_cmd = min(sqrt(2 * a_brake * d), speed cap),  d = distance - speed * response_lag
    i.e. full speed while far away, then braking at a_brake so the drone
    can stop at the target. Braking starts early by the distance covered
    during response_lag, the time the drone takes to tilt from full
    acceleration to full braking; without it the drone overshoots.

    Feedforward, so PX4 tilts to the limit immediately instead of waiting
    for a velocity error to build up (PX4 adds its own velocity feedback on
    top, which corrects any mismatch):
      - accelerating (slower than v_cmd): full acceleration toward the target
      - on the braking curve:             full braking (-a_brake)
      - cruising at the speed cap:        none
    """
    dist = float(np.linalg.norm(err))
    if dist < 1e-6:
        return np.zeros(3), np.zeros(3)
    direction = err / dist

    speed_along = float(np.dot(vel, direction))
    d_brake = max(dist - max(speed_along, 0.0) * response_lag, 0.0)
    v_brake = np.sqrt(2.0 * a_brake * d_brake)
    v_cap = _cap_along(direction, np.inf, v_max_h, v_max_up, v_max_dn)
    v_cmd = min(v_brake, v_cap)

    if speed_along < v_cmd - tol:
        a_ff = _cap_along(direction, np.inf, a_max_h, a_max_up, a_max_dn)
    elif v_brake < v_cap:
        a_ff = -a_brake
    else:
        a_ff = 0.0
    return direction * v_cmd, direction * a_ff


class InterceptSequencer:
    """One intercept attempt at a time, with a defined end.

    READY  -> hover at home; a new object (target stream starting after a
              quiet gap) starts an attempt
    CHASE  -> full-speed chase of the latest intercept point, until
                arrived      within arrive_radius: hold at that point
                target lost  no intercept point for target_timeout s: brake
                time limit   max_chase_time s: brake
                too far      more than max_chase_distance m from home: brake
    STOP   -> velocity 0, with full braking feedforward (stop_accel) while
              faster than 1 m/s, until slower than stop_speed; then hold there
    HOLD   -> position hold for hold_time s
    RETURN -> gentle, speed-limited flight back home (return_fn), then READY

    step() returns (state, kind, vector, accel_ff): kind 'velocity' or
    'position' tells the node which setpoint to send.
    """

    def __init__(self, chase_fn, return_fn, arrive_radius=0.1, target_timeout=0.5,
                 max_chase_time=4.0, max_chase_distance=6.0, hold_time=2.0,
                 stop_speed=0.3, stop_accel=12.6, home_radius=0.3, rearm_quiet=1.0,
                 log=print):
        self.stop_accel = stop_accel
        self.chase_fn = chase_fn
        self.return_fn = return_fn
        self.max_chase_distance = max_chase_distance
        self.arrive_radius = arrive_radius
        self.target_timeout = target_timeout
        self.max_chase_time = max_chase_time
        self.hold_time = hold_time
        self.stop_speed = stop_speed
        self.home_radius = home_radius
        self.rearm_quiet = rearm_quiet
        self.log = log
        self.state = 'READY'
        self.t_state = None
        self.hold_point = None
        self.target = None
        self.committed = False        # set by the node: a committed chase ignores 'target lost' and
                                      # 'arrived' (both use live measurements); it ends on its planned time
        self.t_target = -1e9          # time of the latest intercept point
        self.t_episode = -1e9         # time a target stream (re)started after a quiet gap

    def on_target(self, target, now):
        if now - self.t_target > self.rearm_quiet:
            self.t_episode = now
        self.target = np.asarray(target, float)
        self.t_target = now

    def finish(self, now, why):
        """End the current chase early (e.g. the intercept moment passed)."""
        if self.state == 'CHASE':
            self._go('STOP', now, why)

    def _go(self, state, now, why=''):
        if state != 'CHASE':
            self.committed = False
        self.state = state
        self.t_state = now
        self.log(f'{state}' + (f' ({why})' if why else ''))

    def step(self, now, pos, vel, home):
        if self.t_state is None:
            self.t_state = now
        st = self.state

        if st == 'READY':
            if self.t_episode > self.t_state and now - self.t_target < self.target_timeout:
                self._go('CHASE', now, 'new target')
            else:
                return 'READY', 'position', home, None

        if self.state == 'CHASE':
            err = self.target - pos
            if not self.committed and now - self.t_target > self.target_timeout:
                self._go('STOP', now, 'target lost')
            elif now - self.t_state > self.max_chase_time:
                self._go('STOP', now, 'time limit')
            elif np.linalg.norm(pos - home) > self.max_chase_distance:
                self._go('STOP', now, 'too far from home')
            elif not self.committed and np.linalg.norm(err) <= self.arrive_radius:
                self.hold_point = self.target.copy()
                self._go('HOLD', now, 'arrived at intercept point')
            else:
                v, a = self.chase_fn(err, vel)
                return 'CHASE', 'velocity', v, a

        if self.state == 'STOP':
            speed = float(np.linalg.norm(vel))
            if speed > self.stop_speed:
                brake = -vel / speed * self.stop_accel if speed > 1.0 else None
                return 'STOP', 'velocity', np.zeros(3), brake
            self.hold_point = pos.copy()
            self._go('HOLD', now, 'stopped')

        if self.state == 'HOLD':
            if now - self.t_state >= self.hold_time:
                self._go('RETURN', now, 'returning home')
            else:
                return 'HOLD', 'position', self.hold_point, None

        if self.state == 'RETURN':
            err = home - pos
            if np.linalg.norm(err) < self.home_radius:
                if np.linalg.norm(vel) < self.stop_speed:
                    self._go('READY', now, 'home')
                return self.state, 'position', home, None
            v, a = self.return_fn(err, vel)
            return 'RETURN', 'velocity', v, a

        return self.state, 'position', home, None


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

        # Fully automatic mission: arm -> climb to hover height -> hold
        # until a target arrives -> chase it. All positions are PX4 NED
        # (z down), so hover at z = -takeoff_height.
        self.declare_parameter('takeoff_height', 4.0)
        self.declare_parameter('min_target_height', 0.3)  # never dive below this
        self.takeoff_height = self.get_parameter('takeoff_height').value
        self.min_target_height = self.get_parameter('min_target_height').value
        # How to chase the target:
        #  'position' - send the intercept point as a position setpoint. PX4
        #    then flies at MPC_XY_P (0.95) * distance m/s, i.e. it slows down
        #    exponentially and arrives late.
        #  'velocity' - send a velocity setpoint at full speed toward the
        #    point plus an acceleration feedforward (see chase_command),
        #    switching to a position hold once within arrive_radius. Limits
        #    should match PX4's MPC_* params.
        self.declare_parameter('chase_mode', 'thrust')
        self.declare_parameter('v_max_h', 12.0)   # m/s, <= MPC_XY_VEL_MAX
        self.declare_parameter('v_max_up', 6.0)   # m/s, <= MPC_Z_VEL_MAX_UP
        self.declare_parameter('v_max_dn', 4.0)   # m/s, <= MPC_Z_VEL_MAX_DN
        self.declare_parameter('a_brake', 8.0)    # m/s^2 braking on final approach
        # Acceleration feedforward magnitudes (velocity mode); match the
        # drone's physical limits / PX4 tilt limit.
        self.declare_parameter('a_max_h', 12.6)   # m/s^2, g*tan(MPC_TILTMAX_AIR)
        self.declare_parameter('a_max_up', 6.3)   # m/s^2, full-thrust climb
        self.declare_parameter('a_max_dn', 7.9)   # m/s^2, descent at minimum thrust
        self.declare_parameter('arrive_radius', 0.1)  # m, switch to position hold
        # s, time to tilt from full acceleration to full braking (estimate;
        # raise it if the drone overshoots the target)
        self.declare_parameter('response_lag', 0.15)
        # 'thrust': our own guidance + attitude/thrust control (see
        # thrust_control.py), sending body rates + thrust to PX4 at 100 Hz.
        self.declare_parameter('tilt_max_deg', 52.0)     # = MPC_TILTMAX_AIR
        self.declare_parameter('tilt_delay', 0.1)        # s, planned time to tilt
        self.declare_parameter('object_gravity', 9.81)   # must match the Kalman filter's gravity
        self.declare_parameter('min_safe_height', 1.0)   # m, never accelerate down below this
        self.declare_parameter('end_margin', 0.15)       # s after the planned intercept time
        # Commit only once the ball estimate has settled
        self.declare_parameter('commit_min_detections', 5)
        self.declare_parameter('commit_min_span', 0.25)      # s between first and latest detection
        self.declare_parameter('commit_max_tilt_deg', 10.0)  # drone must be level...
        self.declare_parameter('commit_max_speed', 0.5)      # ...and nearly still (m/s)
        self.tilt_max = np.radians(self.get_parameter('tilt_max_deg').value)
        self.tilt_delay = self.get_parameter('tilt_delay').value
        self.object_gravity = self.get_parameter('object_gravity').value
        self.min_safe_height = self.get_parameter('min_safe_height').value
        self.end_margin = self.get_parameter('end_margin').value
        self.commit_min_detections = self.get_parameter('commit_min_detections').value
        self.commit_min_span = self.get_parameter('commit_min_span').value
        self.commit_max_tilt = np.radians(self.get_parameter('commit_max_tilt_deg').value)
        self.commit_max_speed = self.get_parameter('commit_max_speed').value
        self.chase_mode = self.get_parameter('chase_mode').value
        self.v_max_h = self.get_parameter('v_max_h').value
        self.v_max_up = self.get_parameter('v_max_up').value
        self.v_max_dn = self.get_parameter('v_max_dn').value
        self.a_brake = self.get_parameter('a_brake').value
        self.a_max_h = self.get_parameter('a_max_h').value
        self.a_max_up = self.get_parameter('a_max_up').value
        self.a_max_dn = self.get_parameter('a_max_dn').value
        self.arrive_radius = self.get_parameter('arrive_radius').value
        self.response_lag = self.get_parameter('response_lag').value

        # End of an attempt (see InterceptSequencer)
        self.declare_parameter('target_timeout', 0.5)   # s without a new intercept point -> stop
        self.declare_parameter('max_chase_time', 4.0)   # s, longest chase
        self.declare_parameter('max_chase_distance', 6.0)  # m from home, chase limit
        self.declare_parameter('return_speed', 2.0)     # m/s, flight back home
        self.declare_parameter('return_accel', 2.0)     # m/s^2, flight back home
        self.declare_parameter('hold_time', 2.0)        # s to hold after the attempt
        self.declare_parameter('rearm_quiet', 1.0)      # s of no targets before a new attempt
        self.declare_parameter('yaw_cmd_timeout', 0.3)  # s, stop yawing on stale /rotate_command
        self.yaw_cmd_timeout = self.get_parameter('yaw_cmd_timeout').value
        self.sequencer = InterceptSequencer(
            chase_fn=self._chase,
            return_fn=self._return,
            arrive_radius=self.arrive_radius,
            target_timeout=self.get_parameter('target_timeout').value,
            max_chase_time=self.get_parameter('max_chase_time').value,
            max_chase_distance=self.get_parameter('max_chase_distance').value,
            stop_accel=self.a_brake,
            hold_time=self.get_parameter('hold_time').value,
            rearm_quiet=self.get_parameter('rearm_quiet').value,
            log=lambda m: self.get_logger().info(f'Intercept: {m}'))
        self.t_yaw_cmd = -1e9
        self.yaw_hold = None

        self.position = None
        self.velocity = np.zeros(3)
        self.q = None                # attitude [w, x, y, z], body FRD -> NED
        self.ball = None             # (position NED, velocity NED, capture time s)
        # Committed chase (thrust mode): the ball's path is frozen when the
        # chase starts; the chase ends end_margin s after the planned
        # intercept time, never before.
        self.frozen_ball = None      # (position, velocity, capture time) at chase start
        self.t_end = None            # sim time at which the committed chase ends
        self.detections = []         # capture times of ball states in the current episode
        self.detections_episode = None
        self.hold_xy = None
        self.hover_reached = False

        self.intercept_sub = self.create_subscription(
            PoseStamped, '/planning/intercept_ellipsoid', self.intercept_callback, qos)
        self.rotate_cmd_sub = self.create_subscription(
            Vector3, '/rotate_command', self.rotate_command_callback, 10)

        self.odom_sub = self.create_subscription(
            VehicleOdometry, '/fmu/out/vehicle_odometry', self.odom_callback, qos)

        self.attitude_sub = self.create_subscription(
            VehicleAttitude, '/fmu/out/vehicle_attitude', self.attitude_callback, qos)

        self.ball_sub = self.create_subscription(
            Odometry, '/estimation/object_state', self.ball_callback, qos)

        self.offboard_mode_pub = self.create_publisher(OffboardControlMode, '/fmu/in/offboard_control_mode', qos)
        self.trajectory_pub = self.create_publisher(TrajectorySetpoint, '/fmu/in/trajectory_setpoint', qos)
        self.vehicle_command_pub = self.create_publisher(VehicleCommand, '/fmu/in/vehicle_command', qos)

        # PX4 needs a steady stream of setpoints flowing for a short
        # while before it will accept an offboard mode switch/arm
        # request — count cycles rather than using a wall-clock timer,
        # so this is robust to sim-time speedup/slowdown.
        self.setpoint_counter = 0
        self.arm_after_n_setpoints = 100   # 1 s of setpoints at 100 Hz
        self.armed_and_offboard = False

        # Must publish continuously at >= 2Hz regardless of new data.
        # 100 Hz: the thrust-mode chase closes the attitude loop here.
        self.timer = self.create_timer(0.01, self.publish_setpoints)

        self.get_logger().info('Offboard intercept node started')

    def _now(self):
        return self.get_clock().now().nanoseconds * 1e-9

    def _chase(self, err, vel):
        if self.chase_mode != 'velocity':      # 'thrust' / 'position': handled in publish_setpoints
            return None, None
        return chase_command(err, vel, self.v_max_h, self.v_max_up, self.v_max_dn,
                             self.a_max_h, self.a_max_up, self.a_max_dn, self.a_brake,
                             self.response_lag)

    def _return(self, err, vel):
        # Same braking-curve law as the chase, but slow and gentle so the
        # drone doesn't race home at the full PX4 speed limit.
        v_r = self.get_parameter('return_speed').value
        a_r = self.get_parameter('return_accel').value
        return chase_command(err, vel, v_r, v_r, v_r, a_r, a_r, a_r, a_r, self.response_lag)

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
        target = np.array([msg.pose.position.x, msg.pose.position.y, msg.pose.position.z])
        # NED: don't command a point below min_target_height above ground
        target[2] = min(target[2], -self.min_target_height)
        self.target_position = target
        if self.chase_mode != 'thrust':   # thrust mode starts/ends on the ball state instead
            self.sequencer.on_target(target, self._now())

    def odom_callback(self, msg: VehicleOdometry):
        self.position = np.array([msg.position[0], msg.position[1], msg.position[2]])
        if msg.velocity_frame == VehicleOdometry.VELOCITY_FRAME_NED and np.all(np.isfinite(msg.velocity)):
            self.velocity = np.array([msg.velocity[0], msg.velocity[1], msg.velocity[2]])
        if self.hold_xy is None:
            self.hold_xy = self.position[:2].copy()

    def ball_callback(self, msg: Odometry):
        # Kalman filter state in PX4's NED world frame; the header stamp is
        # the image capture time, so its age can be compensated.
        p = msg.pose.pose.position
        v = msg.twist.twist.linear
        stamp = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9
        self.ball = (np.array([p.x, p.y, p.z]), np.array([v.x, v.y, v.z]), stamp)
        if self.chase_mode == 'thrust':
            self.sequencer.on_target(self.ball[0], self._now())
            if self.detections_episode != self.sequencer.t_episode:   # new object -> restart count
                self.detections_episode = self.sequencer.t_episode
                self.detections = []
            self.detections.append(stamp)

    def attitude_callback(self, msg: VehicleAttitude):
        self.q = np.array([msg.q[0], msg.q[1], msg.q[2], msg.q[3]])
        # PX4 VehicleAttitude.q is [w, x, y, z]
        q_scipy = np.array([msg.q[1], msg.q[2], msg.q[3], msg.q[0]])
        self.current_yaw = Rotation.from_quat(q_scipy).as_euler('xyz')[2]

    def rotate_command_callback(self, msg: Vector3):
        # Only yaw (z) is usable here — pitch/roll aren't directly
        # commandable via TrajectorySetpoint on a quadrotor.
        self.yaw_offset = msg.z
        self.t_yaw_cmd = self._now()

    def _yaw_setpoint(self, now):
        # Follow /rotate_command only while detections keep it fresh;
        # otherwise hold the last heading (a stale offset added to the
        # current yaw every cycle would keep the drone spinning).
        if self.current_yaw is None:
            return float('nan')
        if now - self.t_yaw_cmd < self.yaw_cmd_timeout and self.frozen_ball is None:
            self.yaw_hold = self.current_yaw + self.yaw_offset
        elif self.yaw_hold is None:
            self.yaw_hold = self.current_yaw
        return float(self.yaw_hold)

    def _tilt(self):
        """Angle between body z and vertical (rad), from the PX4 attitude."""
        if self.q is None:
            return np.pi
        w, x, y, z = self.q
        return float(np.arccos(np.clip(1.0 - 2.0 * (x * x + y * y), -1.0, 1.0)))

    def _estimate_settled(self):
        d = self.detections
        return (len(d) >= self.commit_min_detections
                and d[-1] - d[0] >= self.commit_min_span
                and self._tilt() <= self.commit_max_tilt
                and float(np.linalg.norm(self.velocity)) <= self.commit_max_speed)

    def _thrust_chase(self, now):
        """One 100 Hz step of our own intercept guidance.

        Returns ('hold', None) while waiting for the ball estimate to settle,
        ('accel', a) with the NED acceleration to command, or None when the
        chase is over. PX4 turns the acceleration into tilt + thrust in its
        own fast loops (no attitude loop over ROS).

        Settle: wait for commit_min_detections ball states spanning
        commit_min_span s, with the drone level and nearly still, so the
        committed velocity estimate is good (a commit after 2 detections had
        the ball's direction wrong).
        Commit: then the ball's predicted path is frozen. Measurements taken
        while the drone manoeuvres are unreliable (the body-fixed camera
        tilts away from the ball and fast rotation corrupts the
        localisation), so they are ignored; the guidance keeps re-planning
        from the drone's own state every cycle.
        End: end_margin s after the planned intercept time, never before -
        the drone never brakes ahead of the intercept.
        """
        if self.frozen_ball is None:
            if self.ball is None or not self._estimate_settled():
                return 'hold', None
            self.frozen_ball = self.ball
            self.sequencer.committed = True
            d = self.detections
            self.get_logger().info(
                f'Intercept: committed to the ball path ({len(d)} detections over '
                f'{d[-1] - d[0]:.2f} s, ball velocity {np.round(self.ball[1], 2)} m/s)')
        bp, bv, stamp = self.frozen_ball
        age = max(now - stamp, 0.0)
        g = self.object_gravity
        bp_now = ball_position(age, bp, bv, g)
        bv_now = bv + np.array([0.0, 0.0, g * age])

        a, t_go, feasible = intercept_accel(
            self.position, self.velocity, bp_now, bv_now, g,
            self.a_max_h, self.a_max_up, self.a_max_dn, delay=self.tilt_delay)

        # Planned intercept time: fixed once the intercept is imminent; the
        # chase ends end_margin after it.
        if self.t_end is None and t_go <= 0.15:
            self.t_end = now + t_go + self.end_margin
        if self.t_end is not None and now >= self.t_end:
            dist = float(np.linalg.norm(bp_now - self.position))
            self.sequencer.finish(now, f'planned intercept time passed (predicted gap {dist:.2f} m)')
            return None

        # Ground safety: no downward acceleration close to the ground (NED z down)
        if -self.position[2] < self.min_safe_height:
            a[2] = min(a[2], -2.0)
        return 'accel', a

    def publish_setpoints(self):
        # Published every cycle, regardless of whether a target exists
        # yet — PX4 requires this heartbeat at >= 2Hz continuously, or
        # it will never accept/maintain offboard mode.
        position_sp = None
        velocity_sp = None
        accel_ff = None
        accel_cmd = None             # thrust mode: acceleration-only setpoint
        now = self._now()
        yaw = self._yaw_setpoint(now)

        if self.position is not None and self.hold_xy is not None:
            hover_z = -self.takeoff_height
            home = np.array([self.hold_xy[0], self.hold_xy[1], hover_z])
            if not self.hover_reached and abs(self.position[2] - hover_z) < 0.3:
                self.hover_reached = True
                self.get_logger().info('Hover height reached — waiting for / chasing target')

            if not self.hover_reached:
                position_sp = home
            else:
                state, kind, vec, acc = self.sequencer.step(now, self.position, self.velocity, home)
                if state == 'CHASE' and self.chase_mode == 'thrust':
                    res = self._thrust_chase(now)
                    if res is None:                 # chase just ended -> brake this cycle
                        velocity_sp = np.zeros(3)
                        accel_ff = np.full(3, np.nan)
                    elif res[0] == 'hold':          # waiting for the estimate to settle
                        position_sp = home
                    else:
                        accel_cmd = res[1]
                elif kind == 'velocity' and vec is not None:
                    velocity_sp = vec
                    accel_ff = acc if acc is not None else np.full(3, np.nan)
                elif state == 'CHASE':          # chase_mode 'position'
                    position_sp = self.sequencer.target
                else:
                    position_sp = vec
                if state != 'CHASE':
                    self.frozen_ball = None
                    self.t_end = None

        stamp_us = int(self.get_clock().now().nanoseconds / 1000)
        offboard_msg = OffboardControlMode()
        offboard_msg.position = accel_cmd is None and velocity_sp is None
        offboard_msg.velocity = accel_cmd is None and velocity_sp is not None
        offboard_msg.acceleration = accel_cmd is not None
        offboard_msg.attitude = False
        offboard_msg.body_rate = False
        offboard_msg.timestamp = stamp_us
        self.offboard_mode_pub.publish(offboard_msg)

        if position_sp is None and velocity_sp is None and accel_cmd is None:
            return
        traj_msg = TrajectorySetpoint()
        if accel_cmd is not None:
            traj_msg.position = [float('nan')] * 3
            traj_msg.velocity = [float('nan')] * 3
            traj_msg.acceleration = [float(a) for a in accel_cmd]
        elif velocity_sp is not None:
            traj_msg.position = [float('nan')] * 3
            traj_msg.velocity = [float(v) for v in velocity_sp]
            traj_msg.acceleration = [float(a) for a in accel_ff]
        else:
            traj_msg.position = [float(v) for v in position_sp]
            traj_msg.velocity = [float('nan')] * 3
            traj_msg.acceleration = [float('nan')] * 3
        traj_msg.yaw = yaw
        traj_msg.timestamp = stamp_us
        self.trajectory_pub.publish(traj_msg)

        self.setpoint_counter += 1

        if not self.armed_and_offboard and self.setpoint_counter >= self.arm_after_n_setpoints:
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