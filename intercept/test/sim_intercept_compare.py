#!/usr/bin/env python3
"""Offline comparison: old chase (PX4 velocity loop + feedforward toward the
predictor's point) vs new guidance (thrust_control.intercept_accel).

Both share the same inner loops, modelled on PX4 + the simulated x500:
acceleration -> tilt/thrust (accel_to_attitude), attitude P control ->
body rates (attitude_rates), rates tracked with a first-order lag, motor
command (motor_command) -> rotor speed with the model's 0.0125 s motor time
constant -> thrust. Ball estimates arrive at 20 Hz, 0.12 s after capture,
with noise; both methods only see those. Prints the closest approach.
Not a substitute for Gazebo, but it isolates the guidance difference.
"""
import sys
import numpy as np

sys.path.insert(0, __file__.rsplit('/test/', 1)[0])
from intercept.thrust_control import (G, K_THRUST, W_MIN, W_MAX, MASS, N_ROTORS,   # noqa: E402
                                      accel_to_attitude, quat_from_body_z, attitude_rates,
                                      motor_command, rot_from_quat, quat_mul,
                                      intercept_accel, ball_position)
from intercept.intercept_node import chase_command                                 # noqa: E402

TILT = np.radians(52)
LIM = dict(a_max_h=12.6, a_max_up=6.3, a_max_dn=7.9)


def solver_point(drone_p, ball_p, ball_v):
    """The predictor's answer: earliest point the drone could reach *from
    rest* (independent axes, its a/v limits), as published today."""
    a_h, v_h, a_v, v_v = 12.6, 20.0, 6.3, 4.0

    def tt(d, a, vm):
        d = abs(d)
        da = vm * vm / (2 * a)
        return vm / a + (d - da) / vm if d >= da else np.sqrt(2 * d / a)
    for t in np.arange(0.01, 3.0, 0.01):
        b = ball_position(t, ball_p, ball_v, G)
        dlt = b - drone_p
        need = max(tt(dlt[0], a_h, v_h), tt(dlt[1], a_h, v_h), tt(dlt[2], a_v, v_v))
        if need <= t:
            return b
    return None


def run(method, ball_p0, ball_v0, seed=0, T=2.0, dt=0.001, latency=0.12, t_first=0.1):
    rng = np.random.default_rng(seed)
    p = np.array([0.0, 0.0, -4.0]); v = np.zeros(3)
    q = np.array([1.0, 0, 0, 0]); w = np.zeros(3)            # attitude, body rates
    rotor = np.full(4, W_MIN + (W_MAX - W_MIN) * motor_command(G))
    est = None; target = None
    a_cmd = np.zeros(3); rates_sp = np.zeros(3); u = motor_command(G)
    dmin, t_min = 1e9, None
    for k in range(int(T / dt)):
        t = k * dt
        # ball truth
        bp = ball_position(t, ball_p0, ball_v0, G); bv = ball_v0 + np.array([0, 0, G * t])
        d = np.linalg.norm(bp - p)
        if d < dmin:
            dmin, t_min = d, t
        # ball estimate: 20 Hz, captured `latency` ago, noisy
        if t >= t_first + latency and k % 50 == 0:
            tc = t - latency
            est = (ball_position(tc, ball_p0, ball_v0, G) + rng.normal(0, 0.03, 3),
                   ball_v0 + np.array([0, 0, G * tc]) + rng.normal(0, 0.2, 3), tc)
            if method == 'old':
                target = solver_point(p, est[0], est[1])
        # outer loop at 100 Hz
        if k % 10 == 0:
            if est is None:
                a_cmd = -1.8 * v + 0.95 * 1.8 * (np.array([0, 0, -4.0]) - p)   # hover hold
            elif method == 'new':
                age = t - est[2]
                bp_now = ball_position(age, est[0], est[1], G)
                bv_now = est[1] + np.array([0, 0, G * age])
                a_cmd, _, _ = intercept_accel(p, v, bp_now, bv_now, G, **LIM)
            else:
                if target is not None:
                    vs, ff = chase_command(target - p, v, 20, 8, 4, 12.6, 6.3, 7.9, 12.6, 0.15)
                    a_cmd = ff + 1.8 * (vs - v)
            body_z, f = accel_to_attitude(a_cmd, TILT)
            rates_sp = attitude_rates(q, quat_from_body_z(body_z, 0.0))
            u = motor_command(f)
        # inner dynamics at 1 kHz
        w += (rates_sp - w) * dt / 0.03                         # PX4 rate loop ~30 ms
        dq = 0.5 * quat_mul(q, np.r_[0.0, w]); q = q + dq * dt; q /= np.linalg.norm(q)
        w_cmd = W_MIN + (W_MAX - W_MIN) * u
        rotor += (w_cmd - rotor) * dt / 0.0125                  # motor time constant
        thrust = N_ROTORS * K_THRUST * np.mean(rotor) ** 2 / MASS
        acc = rot_from_quat(q) @ np.array([0, 0, -thrust]) + np.array([0, 0, G])
        v += acc * dt; p += v * dt
    return dmin, t_min


SCENARIOS = {
    # NED: x north, y east, z down. Drone hovers at (0, 0, -4) facing east.
    'straight up, 2 m ahead (launch_ball.py 2.0 0.3 3.0 0 0 5.0)': ((0.3, 2.0, -3.0), (0, 0, -5.0)),
    'lob toward drone (launch_ball.py 4.0 0.3 3.5 -3.5 0 4.5)':     ((0.3, 4.0, -3.5), (0, -3.5, -4.5)),
    'straight up, 2.5 m ahead, 1 m left':                           ((-1.0, 2.5, -3.0), (0, 0, -5.0)),
}
if __name__ == '__main__':
    for name, (bp, bv) in SCENARIOS.items():
        res = {m: [run(m, np.array(bp, float), np.array(bv, float), seed=s)[0] for s in range(5)]
               for m in ('old', 'new')}
        print(f'{name}\n   closest approach over 5 noisy runs:'
              f'  old {np.mean(res["old"]):.2f} m (worst {max(res["old"]):.2f})'
              f'  |  new {np.mean(res["new"]):.2f} m (worst {max(res["new"]):.2f})')
