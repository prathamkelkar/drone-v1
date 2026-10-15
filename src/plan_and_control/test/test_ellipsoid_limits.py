import numpy as np

from plan_and_control.trajectory_predictor_ellipsoid import InterceptSolver


def test_vertical_limits_distinguish_climb_and_descent():
    solver = InterceptSolver(
        a_max_h=9.80665,
        a_max_up=5.0,
        a_max_dn=4.0,
        v_max_h=20.0,
        v_max_up=8.0,
        v_max_dn=3.0,
    )

    up = np.array([0.0, 0.0, 1.0])
    down = np.array([0.0, 0.0, -1.0])

    assert np.isclose(solver.effective_accel(up), 5.0)
    assert np.isclose(solver.effective_accel(down), 4.0)
    assert np.isclose(solver.effective_velocity(up), 8.0)
    assert np.isclose(solver.effective_velocity(down), 3.0)


def test_horizontal_limits_are_unchanged():
    solver = InterceptSolver()
    horizontal = np.array([1.0, 0.0, 0.0])

    assert np.isclose(solver.effective_accel(horizontal), 9.80665)
    assert np.isclose(solver.effective_velocity(horizontal), 20.0)
