"""Pure geometry helpers for the intercept node (no ROS imports, unit-tested)."""
import math

# mavros_msgs/PositionTarget type_mask bits (copied so this module stays ROS-free;
# test_setpoint_utils checks them against the message definition when available).
IGNORE_PX = 1
IGNORE_PY = 2
IGNORE_PZ = 4
IGNORE_VX = 8
IGNORE_VY = 16
IGNORE_VZ = 32
IGNORE_AFX = 64
IGNORE_AFY = 128
IGNORE_AFZ = 256
IGNORE_YAW = 1024
IGNORE_YAW_RATE = 2048

# The FORCE bit (512) is deliberately never set: it means "interpret the
# accel field as force", not "ignore force".


IGNORE_POSITION = IGNORE_PX | IGNORE_PY | IGNORE_PZ
IGNORE_VELOCITY = IGNORE_VX | IGNORE_VY | IGNORE_VZ
IGNORE_ACCEL = IGNORE_AFX | IGNORE_AFY | IGNORE_AFZ


def _with_yaw(mask, use_yaw):
    return mask | IGNORE_YAW_RATE | (0 if use_yaw else IGNORE_YAW)


def position_type_mask(use_yaw):
    """type_mask for a position setpoint, with or without a yaw target."""
    return _with_yaw(IGNORE_VELOCITY | IGNORE_ACCEL, use_yaw)


def velocity_type_mask(use_accel, use_yaw):
    """
    Return the type_mask for a velocity setpoint, optionally with accel feedforward.

    ArduPilot GUIDED accepts velocity and velocity + acceleration.
    """
    return _with_yaw(IGNORE_POSITION | (0 if use_accel else IGNORE_ACCEL), use_yaw)


def accel_type_mask(use_yaw):
    """type_mask for an acceleration-only setpoint (ArduCopter 4.1+ GUIDED)."""
    return _with_yaw(IGNORE_POSITION | IGNORE_VELOCITY, use_yaw)


def is_finite_point(p):
    """Return True if every coordinate is a finite number."""
    return all(math.isfinite(float(c)) for c in p)


def clamp_to_box(p, lo, hi):
    """
    Clamp point p to the axis-aligned box [lo, hi].

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
    """
    Return the yaw (rotation about +z) of a quaternion, in radians, in (-pi, pi].

    For an ENU/FLU pose this is the heading measured counter-clockwise
    from east (+x).
    """
    return math.atan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z))


def wrap_angle(a):
    """Wrap an angle to (-pi, pi]."""
    return math.atan2(math.sin(a), math.cos(a))


def yaw_toward_camera_offset(current_yaw, camera_yaw_offset):
    """
    Return the yaw setpoint (ENU, CCW positive) that turns toward the object.

    rotate_command publishes the camera-relative angle with POSITIVE meaning
    "object is to the RIGHT of centre". In ENU, turning right is a NEGATIVE
    (clockwise) yaw change, hence the minus sign. (Under PX4's NED the same
    offset was added, because NED yaw is clockwise-positive.)
    """
    return wrap_angle(current_yaw - camera_yaw_offset)
