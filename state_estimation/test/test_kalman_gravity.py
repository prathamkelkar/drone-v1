"""Gravity sign of the object Kalman filter in ENU (z up). Pure numpy, no ROS."""
import numpy as np
import pytest

from state_estimation.kalman_filter import KalmanFilter

G = 9.81
Z0 = 4.0


def run_free_fall(rate_hz, t_end, g=G):
    """Feed noiseless free-fall measurements from z=Z0, v0=0; return the filter at t_end."""
    kf = KalmanFilter(g=g)
    dt = 1.0 / rate_hz
    kf.initialize(np.array([[1.0], [2.0], [Z0]]))
    n = int(round(t_end / dt))
    for k in range(1, n + 1):
        t = k * dt
        kf.predict(dt)
        kf.update(np.array([[1.0], [2.0], [Z0 - 0.5 * G * t * t]]))
    return kf


@pytest.mark.parametrize('rate_hz', [30.0, 100.0])
def test_free_fall_after_0_3_s(rate_hz):
    kf = run_free_fall(rate_hz, 0.3)
    z, vz = kf.x[2, 0], kf.x[5, 0]
    assert kf.in_flight
    assert vz == pytest.approx(-G * 0.3, abs=0.15)          # ~ -2.94 m/s
    assert z == pytest.approx(Z0 - 0.5 * G * 0.09, abs=0.03)  # ~ 3.56 m
    # x/y are untouched by gravity
    assert kf.x[0, 0] == pytest.approx(1.0, abs=1e-6)
    assert kf.x[1, 0] == pytest.approx(2.0, abs=1e-6)
    assert abs(kf.x[3, 0]) < 1e-6 and abs(kf.x[4, 0]) < 1e-6


def test_gravity_pulls_down_in_predict():
    kf = KalmanFilter(g=G)
    kf.initialize(np.array([[0.0], [0.0], [Z0]]))
    kf.x[5, 0] = -1.0          # already falling -> gate opens
    kf.predict(0.1)
    assert kf.in_flight
    assert kf.x[5, 0] == pytest.approx(-1.0 - G * 0.1)
    assert kf.x[2, 0] == pytest.approx(Z0 - 0.1 - 0.5 * G * 0.01)


def test_rising_object_does_not_open_gate():
    kf = KalmanFilter(g=G)
    kf.initialize(np.array([[0.0], [0.0], [Z0]]))
    kf.x[5, 0] = +2.0          # moving up (ENU) -> not a fall
    kf.predict(0.1)
    assert not kf.in_flight
    assert kf.x[5, 0] == pytest.approx(2.0)


def test_zero_gravity_is_constant_velocity():
    kf = run_free_fall(30.0, 0.3, g=0.0)
    assert kf.x[5, 0] < 0.0    # still tracks the fall, just without a model term
