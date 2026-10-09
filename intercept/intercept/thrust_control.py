"""Our own intercept guidance and thrust/attitude control (no ROS imports).

Pipeline, run at the control rate (100 Hz) while chasing:

  intercept_accel()      drone state + predicted ball path -> acceleration to
                         command and time-to-go. Finds the earliest time t at
                         which a constant acceleration within the drone's
                         limits puts the drone where the ball will be, starting
                         from the drone's *current* position and velocity. Re-
                         solved every cycle, so it is closed-loop guidance.
  accel_to_attitude()    acceleration -> desired body z axis (tilt) + specific
                         thrust, with the tilt limit applied.
  attitude_rates()       desired vs current attitude -> body rate setpoint
                         (P control on the attitude error, like PX4's own
                         attitude controller); PX4 then only tracks the rates.
  motor_command()        specific thrust -> normalized motor command u for
                         VehicleRatesSetpoint.thrust_body, using the simulated
                         x500's rotor model (see below).

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
    with PX4's default gains (MC_ROLL_P/MC_PITCH_P 6.5, MC_YAW_P 2.8) and rate
    limits (MC_ROLLRATE_MAX 220 deg/s)."""
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


def intercept_accel(x, v, ball_p, ball_v, g_ball, a_max_h, a_max_up, a_max_dn,
                    delay=0.0, t_min=0.05, t_max=3.0, dt=0.01, coast_radius=0.15):
    """Constant acceleration that puts the drone (position x, velocity v) on
    the ball's predicted position at the earliest feasible time.

    For a candidate time t the required acceleration is
        a(t) = 2 * (ball(t) - x - v t) / t^2
    and it is feasible if its horizontal part is <= a_max_h and its vertical
    part is within [-a_max_up, a_max_dn] (NED: negative = up). Returns
    (a, t_go, feasible). If no t up to t_max is feasible, returns the
    acceleration for the t that needs the least relative effort, saturated,
    with feasible False (best effort: get as close as possible).

    delay: time the drone needs to tilt before the commanded acceleration
    takes effect. The plan starts from where drone and ball will be after
    it (drone coasting), and the returned t_go includes it.
    """
    # Already on course: if, coasting at the current velocity, the drone
    # passes within coast_radius of the ball before a new command could take
    # effect (delay + t_min), don't plan a later meeting - that would mean
    # braking in the last moment. Keep going (zero extra acceleration;
    # thrust still holds altitude).
    r = ball_p - x
    v_rel = ball_v - v
    vv = float(np.dot(v_rel, v_rel))
    if vv > 1e-6:
        t_c = -float(np.dot(r, v_rel)) / vv
        if 0.0 <= t_c <= delay + t_min:
            miss = ball_position(t_c, ball_p, ball_v, g_ball) - (x + v * t_c)
            if np.linalg.norm(miss) <= coast_radius:
                return np.zeros(3), t_c, True
    if delay > 0.0:
        a, t, ok = intercept_accel(x + v * delay, v, ball_position(delay, ball_p, ball_v, g_ball),
                                   ball_v + np.array([0.0, 0.0, g_ball * delay]), g_ball,
                                   a_max_h, a_max_up, a_max_dn, 0.0, t_min, t_max, dt, coast_radius)
        return a, t + delay, ok
    best = None
    for t in np.arange(t_min, t_max + 1e-9, dt):
        a = 2.0 * (ball_position(t, ball_p, ball_v, g_ball) - x - v * t) / (t * t)
        ah = np.linalg.norm(a[:2])
        az_lim = a_max_dn if a[2] > 0 else a_max_up
        effort = max(ah / a_max_h, abs(a[2]) / az_lim)
        if effort <= 1.0:
            return a, t, True
        if best is None or effort < best[0]:
            best = (effort, a, t)
    effort, a, t = best
    return a / effort, t, False
