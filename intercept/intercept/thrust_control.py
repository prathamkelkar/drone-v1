"""Intercept guidance (used by intercept_node.py) and a model of the
drone's inner loops (used only by the offline simulator).

Used by the node (thrust mode), every 100 Hz control cycle:

  ball_position()        ball position t seconds after a state (p, v),
                         straight line or ballistic depending on gravity.
  intercept_accel()      drone state + predicted ball path -> acceleration to
                         command and time-to-go. Finds the earliest time t at
                         which a constant acceleration within the drone's
                         limits puts the drone where the ball will be, starting
                         from the drone's *current* position and velocity. Re-
                         solved every cycle, so it is closed-loop guidance. The
                         node sends the result to PX4 as an acceleration
                         setpoint; PX4 turns it into tilt + thrust.

Used only by test/sim_intercept_compare.py, to model what PX4 does with
that acceleration (an earlier version of the node ran these itself and sent
body rates + thrust to PX4, which went unstable with the ROS-to-PX4 delay):

  accel_to_attitude()    acceleration -> desired body z axis (tilt) + specific
                         thrust, with the tilt limit applied.
  attitude_rates()       desired vs current attitude -> body rate setpoint
                         (P control on the attitude error, like PX4's own
                         attitude controller).
  motor_command()        specific thrust -> normalized motor command u, using
                         the simulated x500's rotor model (see below).

All vectors are PX4 NED (z down). Quaternions are [w, x, y, z], body FRD ->
NED, as in px4_msgs VehicleAttitude.

Simulated x500 (PX4 Tools/simulation/gz/models): mass 2.125 kg, 4 rotors,
thrust = 8.54858e-6 * w^2 N per rotor, and PX4's gz bridge maps a motor
command u in [0, 1] linearly to w = 150 + 850 u rad/s (SIM_GZ_EC_MIN/MAX).
"""
import numpy as np

G = 9.81
MASS = 2.125
K_THRUST = 8.54858e-06
W_MIN, W_MAX = 150.0, 1000.0
N_ROTORS = 4


def motor_command(specific_thrust, mass=MASS, u_min=0.05):
    """Specific thrust (m/s^2 along body -z) -> normalized motor command."""
    f_rotor = max(specific_thrust, 0.0) * mass / N_ROTORS
    w = np.sqrt(f_rotor / K_THRUST)
    u = (w - W_MIN) / (W_MAX - W_MIN)
    return float(np.clip(u, u_min, 1.0))


def max_specific_thrust(mass=MASS):
    return N_ROTORS * K_THRUST * W_MAX ** 2 / mass   # ~16.1 m/s^2


def accel_to_attitude(a_ned, tilt_max):
    """Desired acceleration -> (body z axis in NED, specific thrust).

    Thrust must produce a - g (NED gravity is +z). If that needs more tilt
    than tilt_max, the horizontal part is scaled down so the vertical part is
    kept (altitude has priority).
    """
    t = np.asarray(a_ned, float) - np.array([0.0, 0.0, G])   # specific thrust vector
    if t[2] > -0.5:                       # never ask for thrust pointing down / near zero
        t[2] = -0.5
    h = np.linalg.norm(t[:2])
    max_h = -t[2] * np.tan(tilt_max)
    if h > max_h:
        t[:2] *= max_h / h
    f = float(np.linalg.norm(t))
    return -t / f, f


def quat_from_body_z(body_z, yaw):
    """Attitude whose body z axis is body_z (NED) with heading yaw
    (same construction as PX4's ControlMath::bodyzToAttitude)."""
    z = body_z / np.linalg.norm(body_z)
    y_c = np.array([-np.sin(yaw), np.cos(yaw), 0.0])
    x = np.cross(y_c, z)
    if np.linalg.norm(x) < 1e-6:          # body z horizontal and along y_c: degenerate
        x = np.array([np.cos(yaw), np.sin(yaw), 0.0])
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    R = np.column_stack([x, y, z])
    return quat_from_rot(R)


def quat_from_rot(R):
    tr = np.trace(R)
    if tr > 0:
        s = np.sqrt(tr + 1.0) * 2
        q = [0.25 * s, (R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s]
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = np.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        q = [(R[2, 1] - R[1, 2]) / s, 0.25 * s, (R[0, 1] + R[1, 0]) / s, (R[0, 2] + R[2, 0]) / s]
    elif R[1, 1] > R[2, 2]:
        s = np.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        q = [(R[0, 2] - R[2, 0]) / s, (R[0, 1] + R[1, 0]) / s, 0.25 * s, (R[1, 2] + R[2, 1]) / s]
    else:
        s = np.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        q = [(R[1, 0] - R[0, 1]) / s, (R[0, 2] + R[2, 0]) / s, (R[1, 2] + R[2, 1]) / s, 0.25 * s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def quat_mul(a, b):
    w1, x1, y1, z1 = a
    w2, x2, y2, z2 = b
    return np.array([w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
                     w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2])


def quat_conj(q):
    return np.array([q[0], -q[1], -q[2], -q[3]])


def rot_from_quat(q):
    w, x, y, z = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
                     [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
                     [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]])


def attitude_rates(q, q_des, k_rp=6.5, k_yaw=2.8, rate_max_rp=3.8, rate_max_yaw=3.5):
    """Body rate setpoint [p, q, r] (rad/s) from the attitude error, P control
    like PX4's attitude controller. Defaults: gain 6.5 (the launch file's
    MC_ROLL_P/MC_PITCH_P; PX4's own default is 4.0), yaw gain 2.8, roll/pitch
    rate limit 3.8 rad/s (PX4's default MC_ROLLRATE_MAX of 220 deg/s; the
    launch file raises it to 480 deg/s)."""
    qe = quat_mul(quat_conj(q), q_des)
    if qe[0] < 0:
        qe = -qe
    e = 2.0 * qe[1:]
    rates = np.array([k_rp * e[0], k_rp * e[1], k_yaw * e[2]])
    rates[:2] = np.clip(rates[:2], -rate_max_rp, rate_max_rp)
    rates[2] = np.clip(rates[2], -rate_max_yaw, rate_max_yaw)
    return rates


def ball_position(t, p, v, g_ball):
    """Ball position t seconds after state (p, v); NED, gravity +z."""
    return p + v * t + np.array([0.0, 0.0, 0.5 * g_ball * t * t])


def timed_intercept_accel(x, v, target, t_go, a_max_h, a_max_up, a_max_dn,
                          delay=0.0, min_time=0.03):
    """Acceleration required to reach ``target`` exactly ``t_go`` seconds
    from now, limited to the drone's horizontal/up/down acceleration bounds.

    During ``delay`` the drone is assumed to keep its current velocity while
    PX4 tilts. The commanded acceleration then acts for the remaining time.
    Returns ``(acceleration, feasible)``; when the exact command exceeds a
    limit it is scaled uniformly to the boundary as a best-effort command.
    """
    x = np.asarray(x, float)
    v = np.asarray(v, float)
    target = np.asarray(target, float)
    t_go = float(t_go)

    # Near the deadline there is no useful time left to model an additional
    # tilt delay; PX4 is already responding to the preceding commands.
    delay_used = delay if t_go > delay + min_time else 0.0
    accel_time = max(t_go - delay_used, min_time)

    # target = x + v*t_go + 0.5*a*accel_time^2
    a = 2.0 * (target - x - v * t_go) / (accel_time * accel_time)
    vertical_limit = a_max_dn if a[2] > 0.0 else a_max_up
    effort = max(float(np.linalg.norm(a[:2])) / a_max_h,
                 abs(float(a[2])) / vertical_limit)
    feasible = effort <= 1.0
    if not feasible:
        a /= effort
    return a, feasible


def _cap_along(direction, lim_h, lim_up, lim_dn):
    """Largest magnitude along unit `direction` within separate horizontal
    and vertical (NED: up = -z) limits."""
    m = np.inf
    h = float(np.linalg.norm(direction[:2]))
    if h > 1e-6:
        m = min(m, lim_h / h)
    lim_z = lim_up if direction[2] < 0 else lim_dn
    if abs(direction[2]) > 1e-6:
        m = min(m, lim_z / abs(direction[2]))
    return m


def intercept_accel(x, v, ball_p, ball_v, g_ball, a_max_h, a_max_up, a_max_dn,
                    delay=0.0, t_min=0.05, t_max=3.0, dt=0.01, terminal_time=0.15):
    """Acceleration that puts the drone (position x, velocity v) on the ball,
    at full effort all the way to the ball - it never eases off or brakes
    before reaching it.

    Main phase: for a candidate time t the constant acceleration needed is
        a(t) = 2 * (ball(t) - x - v t) / t^2
    and it is feasible if its horizontal part is <= a_max_h and its vertical
    part is within [-a_max_up, a_max_dn] (NED: negative = up). The earliest
    feasible t is used, which is a full-effort push. If none up to t_max is
    feasible, the least-effort option is scaled to the limits (best effort).

    Terminal phase: once the drone is closing on the ball and the closest
    approach is at most terminal_time away, the same earliest-time plan is
    made with no tilt delay and no minimum meeting time (the drone is
    already tilted and pushing). With the t_min + delay floor the plan
    asked for less than full acceleration at this range, so the drone eased
    off and tilted back before reaching the ball. Only meeting times up to
    closest approach are considered, so if an exact hit is out of reach the
    command is the full-strength push that minimises the miss.

    Never brake before the ball: while closing, any component of the command
    against the direction of travel is removed.

    delay: time the drone needs to tilt before the commanded acceleration
    takes effect. The main-phase plan starts from where drone and ball will
    be after it (drone coasting), and the returned t_go includes it.

    Returns (a, t_go, feasible).
    """
    r = ball_p - x
    speed = float(np.linalg.norm(v))
    closing = speed > 0.3 and float(np.dot(r, v)) > 0.0

    # Terminal phase: the drone is already tilted and pushing, so plan with
    # no tilt delay and no minimum meeting time - the earliest-time solution
    # is then a correctly-timed full-effort push right into the ball.
    v_rel = ball_v - v
    vv = float(np.dot(v_rel, v_rel))
    if closing and vv > 1e-6:
        t_c = -float(np.dot(r, v_rel)) / vv
        if 0.0 < t_c <= terminal_time:
            # Only meetings up to closest approach count. If an exact hit
            # isn't reachable in that time, the best-effort result is the
            # full-strength push that most reduces the miss - never a plan to
            # turn around and come back later.
            a, t, ok = intercept_accel(x, v, ball_p, ball_v, g_ball, a_max_h, a_max_up, a_max_dn,
                                       0.0, min(dt, t_c), t_c + dt, min(dt, t_c), 0.0)
            return _no_braking(a, v, closing), t, ok

    if delay > 0.0:
        a, t, ok = intercept_accel(x + v * delay, v, ball_position(delay, ball_p, ball_v, g_ball),
                                   ball_v + np.array([0.0, 0.0, g_ball * delay]), g_ball,
                                   a_max_h, a_max_up, a_max_dn, 0.0, t_min, t_max, dt, 0.0)
        return _no_braking(a, v, closing), t + delay, ok
    def required(t):
        a = 2.0 * (ball_position(t, ball_p, ball_v, g_ball) - x - v * t) / (t * t)
        az_lim = a_max_dn if a[2] > 0 else a_max_up
        return a, max(np.linalg.norm(a[:2]) / a_max_h, abs(a[2]) / az_lim)

    best = None
    t_prev = None
    for t in np.arange(t_min, t_max + 1e-9, dt):
        a, effort = required(t)
        if effort <= 1.0:
            # Refine the earliest feasible time between the last infeasible
            # step and this one, so the push is exactly at the limit (near the
            # ball the needed acceleration changes a lot within one dt step).
            if t_prev is not None:
                lo, hi = t_prev, t
                for _ in range(20):
                    mid = 0.5 * (lo + hi)
                    if required(mid)[1] <= 1.0:
                        hi = mid
                    else:
                        lo = mid
                t = hi
                a, effort = required(t)
            return _no_braking(a, v, closing), t, True
        t_prev = t
        if best is None or effort < best[0]:
            best = (effort, a, t)
    effort, a, t = best
    return _no_braking(a / effort, v, closing), t, False


def _no_braking(a, v, closing):
    """While closing on the ball, drop any part of `a` that opposes the
    direction of travel (steering sideways is still allowed)."""
    if not closing:
        return a
    vhat = v / np.linalg.norm(v)
    along = float(np.dot(a, vhat))
    return a - along * vhat if along < 0.0 else a
