"""Pure geometry helpers for the intercept node (no ROS imports, unit-tested)."""
import math

# mavros_msgs/PositionTarget type_mask bits (copied so this module stays ROS-free;
# test_setpoint_utils checks them against the message definition when available).
IGNORE_VX = 8
IGNORE_VY = 16
IGNORE_VZ = 32
IGNORE_AFX = 64
IGNORE_AFY = 128
IGNORE_AFZ = 256
IGNORE_YAW = 1024
IGNORE_YAW_RATE = 2048

# Position (+ optional yaw) only. The FORCE bit (512) is deliberately NOT set:
# it means "interpret the accel field as force", not "ignore force", and the
# accel field is ignored anyway.
POSITION_ONLY_MASK = (IGNORE_VX | IGNORE_VY | IGNORE_VZ |
                      IGNORE_AFX | IGNORE_AFY | IGNORE_AFZ |
                      IGNORE_YAW_RATE)


def position_type_mask(use_yaw):
    """type_mask for a position setpoint, with or without a yaw target."""
    return POSITION_ONLY_MASK if use_yaw else POSITION_ONLY_MASK | IGNORE_YAW


def is_finite_point(p):
    """True if every coordinate is a finite number."""
    return all(math.isfinite(float(c)) for c in p)


def clamp_to_box(p, lo, hi):
    """Clamp point p to the axis-aligned box [lo, hi].

    Returns (clamped_point_as_list, was_clamped).
    """
    out = []
    clamped = False
    for c, a, b in zip(p, lo, hi):
        v = min(max(float(c), a), b)
        clamped = clamped or v != float(c)
        out.append(v)
    return out, clamped


def yaw_from_quaternion(x, y, z, w):
    """Yaw (rotation about +z) of a quaternion, in radians, in (-pi, pi].

    For an ENU/FLU pose this is the heading measured counter-clockwise
    from east (+x).
    """
    return math.atan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z))


def wrap_angle(a):
    """Wrap an angle to (-pi, pi]."""
    return math.atan2(math.sin(a), math.cos(a))


def yaw_toward_camera_offset(current_yaw, camera_yaw_offset):
    """Yaw setpoint (ENU, CCW positive) that turns toward the object.

    rotate_command publishes the camera-relative angle with POSITIVE meaning
    "object is to the RIGHT of centre". In ENU, turning right is a NEGATIVE
    (clockwise) yaw change, hence the minus sign. (Under PX4's NED the same
    offset was added, because NED yaw is clockwise-positive.)
    """
    return wrap_angle(current_yaw - camera_yaw_offset)
