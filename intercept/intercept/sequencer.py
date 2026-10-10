"""
Intercept attempt sequencing and the velocity-mode chase law.

Pure numpy, no ROS; used by intercept_node.py and test/sim_intercept_compare.py.

All vectors are ENU (x east, y north, z up).
"""
from intercept.thrust_control import cap_along
import numpy as np


def chase_command(err, vel, v_max_h, v_max_up, v_max_dn,
                  a_max_h, a_max_up, a_max_dn, a_brake, response_lag=0.15, tol=0.3,
                  brake=True):
    """
    Velocity setpoint and acceleration feedforward (both ENU) toward a point.

    Closes position error `err` as fast as possible, given current velocity `vel`.

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

    Feedforward, so the autopilot tilts to the limit immediately instead of
    waiting for a velocity error to build up (its own velocity feedback on
    top corrects any mismatch):
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
        v_cap = cap_along(direction, v_max_h, v_max_up, v_max_dn)
        a_ff = cap_along(direction, a_max_h, a_max_up, a_max_dn) \
            if speed_along < v_cap - tol else 0.0
        return direction * v_cap, direction * a_ff
    d_brake = max(dist - max(speed_along, 0.0) * response_lag, 0.0)
    v_brake = np.sqrt(2.0 * a_brake * d_brake)
    v_cap = cap_along(direction, v_max_h, v_max_up, v_max_dn)
    v_cmd = min(v_brake, v_cap)

    if speed_along < v_cmd - tol:
        a_ff = cap_along(direction, a_max_h, a_max_up, a_max_dn)
    elif v_brake < v_cap:
        a_ff = -a_brake
    else:
        a_ff = 0.0
    return direction * v_cmd, direction * a_ff


class InterceptSequencer:
    """
    One intercept attempt at a time, with a defined end.

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
    'position' tells the node which setpoint to send. Frame-agnostic apart
    from chase_fn / return_fn (ENU in this package).
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
        # A committed chase ignores 'target lost' and 'passed' (both use live
        # measurements) and ends on its planned time. Never set at present.
        self.committed = False
        self.t_target = -1e9          # time of the latest intercept point
        self.t_episode = -1e9         # time a target stream (re)started after a quiet gap
        self.target_deadline = None   # absolute sim time the object reaches the latest point

    def on_target(self, target, now, deadline=None):
        if now - self.t_target > self.rearm_quiet:
            self.t_episode = now
        self.target = np.asarray(target, float)
        self.t_target = now
        self.target_deadline = deadline

    def reset(self, now, why=''):
        """Back to READY with no target (e.g. after the pilot took over)."""
        self.target = None
        self.target_deadline = None
        self.t_target = -1e9
        self.t_episode = -1e9
        self._go('READY', now, why)

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
