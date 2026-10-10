"""Tests for intercept.setpoint_utils (pure Python, no ROS needed)."""
import math

import pytest

from intercept import setpoint_utils as su


def test_clamp_inside_box_unchanged():
    p, clamped = su.clamp_to_box([1.0, -2.0, 4.0], [-50, -50, 0.3], [50, 50, 20])
    assert p == [1.0, -2.0, 4.0]
    assert not clamped


def test_clamp_outside_box():
    p, clamped = su.clamp_to_box([100.0, -2.0, -1.0], [-50, -50, 0.3], [50, 50, 20])
    assert p == [50.0, -2.0, 0.3]
    assert clamped


def test_is_finite_point():
    assert su.is_finite_point([0.0, 1.0, 2.0])
    assert not su.is_finite_point([0.0, float('nan'), 2.0])
    assert not su.is_finite_point([float('inf'), 0.0, 0.0])


@pytest.mark.parametrize('yaw', [0.0, 0.5, -1.2, math.pi / 2, 3.0])
def test_yaw_from_quaternion_pure_yaw(yaw):
    q = (0.0, 0.0, math.sin(yaw / 2), math.cos(yaw / 2))
    assert su.yaw_from_quaternion(*q) == pytest.approx(yaw)


def test_yaw_from_quaternion_ignores_small_tilt():
    # yaw 0.7 rad, then 10 deg roll about body x: yaw unchanged
    yaw, roll = 0.7, math.radians(10)
    cy, sy = math.cos(yaw / 2), math.sin(yaw / 2)
    cr, sr = math.cos(roll / 2), math.sin(roll / 2)
    # q = q_yaw * q_roll
    w = cy * cr
    x = cy * sr
    y = sy * sr
    z = sy * cr
    assert su.yaw_from_quaternion(x, y, z, w) == pytest.approx(yaw)


def test_object_right_turns_clockwise_in_enu():
    # object to the right (positive offset) -> yaw decreases (clockwise)
    assert su.yaw_toward_camera_offset(0.0, 0.2) == pytest.approx(-0.2)
    assert su.yaw_toward_camera_offset(1.0, -0.3) == pytest.approx(1.3)


def test_yaw_wraps():
    assert su.yaw_toward_camera_offset(-3.0, 0.5) == pytest.approx(-3.5 + 2 * math.pi)


def test_type_masks():
    assert su.position_type_mask(True) == 2552
    assert su.position_type_mask(False) == 2552 | 1024
    assert not su.position_type_mask(True) & 512  # FORCE not set
    assert not su.position_type_mask(True) & 7    # position used


def test_mask_bits_match_mavros():
    pt = pytest.importorskip('mavros_msgs.msg').PositionTarget
    assert su.IGNORE_VX == pt.IGNORE_VX
    assert su.IGNORE_AFZ == pt.IGNORE_AFZ
    assert su.IGNORE_YAW == pt.IGNORE_YAW
    assert su.IGNORE_YAW_RATE == pt.IGNORE_YAW_RATE
