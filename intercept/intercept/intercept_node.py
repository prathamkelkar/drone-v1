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
    VehicleCommand,
    VehicleOdometry
)

from intercept.thrust_control import intercept_accel, timed_intercept_accel

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
                  a_max_h, a_max_up, a_max_dn, a_brake, response_lag=0.15, tol=0.3,
                  brake=True):
    """Velocity setpoint and acceleration feedforward (both NED) to close
    position error `err` as fast as possible, given current velocity `vel`.

    brake=False (chasing an object): full speed toward the point with full
    acceleration until the speed cap - no braking curve at all, so the drone
    reaches the point at full speed or still accelerating. Braking only
    happens after the point is passed (the sequencer ends the chase then).
    brake=True (flying home): the braking curve below, to stop at the point.

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
    if not brake:
        v_cap = _cap_along(direction, np.inf, v_max_h, v_max_up, v_max_dn)
        a_ff = _cap_along(direction, np.inf, a_max_h, a_max_up, a_max_dn) \
            if speed_along < v_cap - tol else 0.0
        return direction * v_cap, direction * a_ff
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
    CHASE  -> full-speed chase of the latest intercept point (never braking
              before it), until
                passed       the point is behind the drone (it was within
                             pass_radius): brake - hit or miss, it's over
                target lost  no intercept point for target_timeout s, after
                             the last point's predicted arrival time: brake
                time limit   max_chase_time s: brake
                too far      more than max_chase_distance m from home: brake
    STOP   -> velocity 0, with full braking feedforward (stop_accel) while
              faster than 1 m/s, until slower than stop_speed; then hold there
    HOLD   -> position hold for hold_time s
    RETURN -> gentle, speed-limited flight back home (return_fn), then READY

    step() returns (state, kind, vector, accel_ff): kind 'velocity' or
    'position' tells the node which setpoint to send.
    """

    def __init__(self, chase_fn, return_fn, pass_radius=1.0, target_timeout=0.5,
                 max_chase_time=4.0, max_chase_distance=6.0, hold_time=2.0,
                 stop_speed=0.3, stop_accel=12.6, home_radius=0.3, rearm_quiet=1.0,
                 deadline_margin=0.15, log=print):
        self.stop_accel = stop_accel
        self.chase_fn = chase_fn
        self.return_fn = return_fn
        self.max_chase_distance = max_chase_distance
        self.pass_radius = pass_radius
        self.target_timeout = target_timeout
        self.max_chase_time = max_chase_time
        self.hold_time = hold_time
        self.stop_speed = stop_speed
        self.home_radius = home_radius
        self.rearm_quiet = rearm_quiet
        self.deadline_margin = deadline_margin
        self.log = log
        self.state = 'READY'
        self.t_state = None
        self.hold_point = None
        self.target = None
        self.committed = False        # set by the node: a committed chase ignores 'target lost' and
                                      # 'passed' (both use live measurements); it ends on its planned time
        self.t_target = -1e9          # time of the latest intercept point
        self.t_episode = -1e9         # time a target stream (re)started after a quiet gap
        self.target_deadline = None   # absolute sim time the object reaches the latest point

    def on_target(self, target, now, deadline=None):
        if now - self.t_target > self.rearm_quiet:
            self.t_episode = now
        self.target = np.asarray(target, float)
        self.t_target = now
        self.target_deadline = deadline

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
            # Losing predictor updates should not abort a valid final plan
            # before the object is due to reach its last published intercept
            # point. Once that deadline passes, the ordinary timeout applies.
            deadline_active = (
                self.target_deadline is not None
                and now <= self.target_deadline + self.deadline_margin
            )
            if (not self.committed
                    and now - self.t_target > self.target_timeout
                    and not deadline_active):
                self._go('STOP', now, 'target lost')
            elif now - self.t_state > self.max_chase_time:
                self._go('STOP', now, 'time limit')
            elif np.linalg.norm(pos - home) > self.max_chase_distance:
                self._go('STOP', now, 'too far from home')
            elif (not self.committed
                  and (self.target_deadline is None or now >= self.target_deadline)
                  and np.linalg.norm(err) <= self.pass_radius
                  and float(np.dot(err, vel)) < 0.0):
                # the point is now behind the drone: we went through it
                self._go('STOP', now, 'passed the intercept point')
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
        #  'thrust' (default) - our own guidance drives toward the latest
        #    point published on /planning/intercept_ellipsoid, sent to PX4 as
        #    an acceleration setpoint at 100 Hz; PX4's own loops turn it into
        #    tilt + thrust. See _thrust_chase.
        #  'velocity' - send a velocity setpoint at full speed toward the
        #    predictor's point plus full acceleration feedforward (see
        #    chase_command, brake=False); braking only starts once the point
        #    is passed. Limits should match PX4's MPC_* params.
        # In both modes the drone reaches the point at full speed or still
        # accelerating - it is trying to hit an object there, not stop there.
        # (A 'position' mode - sending the point as a position setpoint - was
        # removed: PX4 slows down approaching a position setpoint, so it
        # always arrived late.)
        # Defaults below are for running the node on its own; the launch
        # file overrides most of them.
        self.declare_parameter('chase_mode', 'thrust')
        self.declare_parameter('v_max_h', 12.0)   # m/s, <= MPC_XY_VEL_MAX
        self.declare_parameter('v_max_up', 6.0)   # m/s, <= MPC_Z_VEL_MAX_UP
        self.declare_parameter('v_max_dn', 4.0)   # m/s, <= MPC_Z_VEL_MAX_DN
        self.declare_parameter('a_brake', 8.0)    # m/s^2 braking on final approach
        # Acceleration limits: the feedforward magnitudes in velocity mode
        # and the guidance limits in thrust mode; match the drone's physical
        # limits / PX4 tilt limit.
        self.declare_parameter('a_max_h', 12.6)   # m/s^2, g*tan(MPC_TILTMAX_AIR)
        self.declare_parameter('a_max_up', 6.3)   # m/s^2, full-thrust climb
        self.declare_parameter('a_max_dn', 7.9)   # m/s^2, descent at minimum thrust
        self.declare_parameter('pass_radius', 1.0)  # m, point behind us within this -> passed
        # s, time to tilt from full acceleration to full braking (estimate;
        # raise it if the drone overshoots the target)
        self.declare_parameter('response_lag', 0.15)
        # Thrust mode (see _thrust_chase)
        self.declare_parameter('tilt_max_deg', 52.0)     # = MPC_TILTMAX_AIR; not used by the node (PX4 enforces the tilt limit)
        self.declare_parameter('tilt_delay', 0.1)        # s, planned time to tilt
        self.declare_parameter('min_safe_height', 0.3)   # m, never accelerate down below this
        self.declare_parameter('end_margin', 0.15)       # s to keep pushing through after arrival time
        # s: in the last terminal_time before closest approach, plan with no
        # tilt delay / minimum meeting time so the push stays at full effort
        # right into the ball (see thrust_control.intercept_accel)
        self.declare_parameter('terminal_time', 0.15)
        self.tilt_max = np.radians(self.get_parameter('tilt_max_deg').value)
        self.tilt_delay = self.get_parameter('tilt_delay').value
        self.min_safe_height = self.get_parameter('min_safe_height').value
        self.terminal_time = self.get_parameter('terminal_time').value
        self.chase_mode = self.get_parameter('chase_mode').value
        self.v_max_h = self.get_parameter('v_max_h').value
        self.v_max_up = self.get_parameter('v_max_up').value
        self.v_max_dn = self.get_parameter('v_max_dn').value
        self.a_brake = self.get_parameter('a_brake').value
        self.a_max_h = self.get_parameter('a_max_h').value
        self.a_max_up = self.get_parameter('a_max_up').value
        self.a_max_dn = self.get_parameter('a_max_dn').value
        self.pass_radius = self.get_parameter('pass_radius').value
        if self.chase_mode not in ('thrust', 'velocity'):
            raise ValueError(f"chase_mode must be 'thrust' or 'velocity', not {self.chase_mode!r}")
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
            pass_radius=self.pass_radius,
            target_timeout=self.get_parameter('target_timeout').value,
            max_chase_time=self.get_parameter('max_chase_time').value,
            max_chase_distance=self.get_parameter('max_chase_distance').value,
            stop_accel=self.a_brake,
            hold_time=self.get_parameter('hold_time').value,
            rearm_quiet=self.get_parameter('rearm_quiet').value,
            deadline_margin=self.get_parameter('end_margin').value,
            log=lambda m: self.get_logger().info(f'Intercept: {m}'))
        self.t_yaw_cmd = -1e9
        self.yaw_hold = None

        self.position = None
        self.velocity = np.zeros(3)
        self.q = None                # attitude [w, x, y, z], body FRD -> NED
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
        # 100 Hz: the thrust-mode guidance re-plans every cycle.
        self.timer = self.create_timer(0.01, self.publish_setpoints)

        self.get_logger().info('Offboard intercept node started')

    def _now(self):
        return self.get_clock().now().nanoseconds * 1e-9

    def _chase(self, err, vel):
        if self.chase_mode != 'velocity':      # 'thrust': handled in publish_setpoints
            return None, None
        # brake=False: full speed through the point, never slowing before it
        return chase_command(err, vel, self.v_max_h, self.v_max_up, self.v_max_dn,
                             self.a_max_h, self.a_max_up, self.a_max_dn, self.a_brake,
                             self.response_lag, brake=False)

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
        deadline = msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9
        # NED: don't command a point below min_target_height above ground
        target[2] = min(target[2], -self.min_target_height)
        self.target_position = target
        # Both chase modes use the predictor's feasible intercept point.
        # In particular, thrust mode must not start directly from the raw/KF
        # ball stream, because that bypasses the predictor's feasibility and
        # minimum-height checks.
        self.sequencer.on_target(target, self._now(), deadline)

    def odom_callback(self, msg: VehicleOdometry):
        self.position = np.array([msg.position[0], msg.position[1], msg.position[2]])
        if msg.velocity_frame == VehicleOdometry.VELOCITY_FRAME_NED and np.all(np.isfinite(msg.velocity)):
            self.velocity = np.array([msg.velocity[0], msg.velocity[1], msg.velocity[2]])
        if self.hold_xy is None:
            self.hold_xy = self.position[:2].copy()

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
        if now - self.t_yaw_cmd < self.yaw_cmd_timeout:
            self.yaw_hold = self.current_yaw + self.yaw_offset
        elif self.yaw_hold is None:
            self.yaw_hold = self.current_yaw
        return float(self.yaw_hold)

    def _thrust_chase(self, now):
        """Reach the predictor's latest point at its stamped arrival time.

        The point and absolute deadline are refreshed by
        /planning/intercept_ellipsoid. At 100 Hz, solve the constant net
        acceleration that takes the drone from its current position and
        velocity to that point in the remaining time. This synchronizes the
        drone's arrival with the object's predicted arrival instead of merely
        reaching the point as soon as possible.

        Returns ('accel', a) with a NED acceleration setpoint. PX4 turns that
        into tilt and thrust in its own inner loops.
        """
        target = self.sequencer.target
        deadline = self.sequencer.target_deadline
        if target is None or deadline is None:
            return 'hold', None

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
                    elif res[0] == 'hold':          # no planned point available yet
                        position_sp = home
                    else:
                        accel_cmd = res[1]
                elif kind == 'velocity' and vec is not None:
                    velocity_sp = vec
                    accel_ff = acc if acc is not None else np.full(3, np.nan)
                else:
                    position_sp = vec
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
