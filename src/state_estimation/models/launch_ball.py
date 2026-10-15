#!/usr/bin/env python3
"""Spawn the ball at (X, Y, Z) and throw it with velocity (VX, VY, VZ) m/s.

Usage: launch_ball.py X Y Z V0             kick straight up at V0
       launch_ball.py X Y Z VX VY VZ       throw in any direction (e.g. a lob)
       With no arguments, reads the live iris_cam pose from Gazebo and starts
       the ball 5.2 m ahead and 0.3 m to the camera's right at camera height,
       with 3.5 m/s velocity toward the camera and 5.5 m/s up. This arc is
       inside the camera FOV and has a feasible intercept under the configured
       ArduPilot controller limits after the launch pulse.
       The spawn direction follows the drone's current yaw.
       Explicit arguments are absolute Gazebo coordinates (x east, y north,
       z up).
       WORLD (env, default iris_runway = ardupilot/worlds/drone_world.sdf)
       selects the Gazebo world name. LAUNCH_DURATION (env, default 0.2) is
       the simulated number of seconds over which the launch impulse is
       applied.

Needs the ApplyLinkWrench system loaded in the Gazebo world, i.e. this line
inside <world> (drone_world.sdf loads it):
  <plugin filename="gz-sim-apply-link-wrench-system"
          name="gz::sim::systems::ApplyLinkWrench"/>

The launch uses Gazebo's persistent-wrench topic for a pulse measured from
the ball's own pose timestamps, then clears it and checks the actual Gazebo
pose samples. A /clock subscriber can lag the pose stream under load; a
predicted apex is not proof of a throw.
"""
import math
import os
import json
import re
import subprocess
import sys
import threading
import time
from collections import deque

from gz.msgs10.entity_pb2 import Entity
from gz.msgs10.entity_wrench_pb2 import EntityWrench
from gz.msgs10.pose_v_pb2 import Pose_V
from gz.transport13 import Node

MASS = 0.43
GRAVITY = 9.81
CAMERA_FORWARD_DISTANCE = 5.2
CAMERA_LATERAL_OFFSET = 0.3
CAMERA_VERTICAL_OFFSET = 0.0
BALL_TOWARD_SPEED = 3.5
BALL_UP_SPEED = 5.5
CAMERA_VERTICAL_FOV = 1.412
LAUNCH_DURATION = float(os.environ.get('LAUNCH_DURATION', '0.2'))
if LAUNCH_DURATION <= 0.0:
    sys.exit('LAUNCH_DURATION must be positive')

camera_relative = len(sys.argv) == 1
if camera_relative:
    x = y = z = None
    vel = None
elif len(sys.argv) == 5:
    x, y, z = (float(v) for v in sys.argv[1:4])
    vel = [0.0, 0.0, float(sys.argv[4])]
elif len(sys.argv) == 7:
    x, y, z = (float(v) for v in sys.argv[1:4])
    vel = [float(v) for v in sys.argv[4:7]]
else:
    sys.exit('usage: launch_ball.py [X Y Z V0 | X Y Z VX VY VZ]')
world = os.environ.get('WORLD', 'iris_runway')
sdf = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'drop_ball.sdf')

node = Node()
persistent_pub = node.advertise(
    f'/world/{world}/wrench/persistent', EntityWrench)
clear_pub = node.advertise(f'/world/{world}/wrench/clear', Entity)

ball_ready = threading.Event()
drone_pose_ready = threading.Event()
drone_pose = None
pose_lock = threading.Lock()
ball_samples = deque(maxlen=300)


def on_poses(msg: Pose_V):
    global drone_pose
    stamp = msg.header.stamp.sec + msg.header.stamp.nsec * 1e-9
    for pose in msg.pose:
        if pose.name == 'drop_ball':
            # An old queued pose must not certify creation of the new ball.
            if not ball_ready.is_set():
                if x is None or math.dist(
                    (pose.position.x, pose.position.y, pose.position.z),
                    (x, y, z),
                ) > 0.2:
                    continue
            with pose_lock:
                if not ball_samples or stamp >= ball_samples[-1][0] + 0.01:
                    ball_samples.append((stamp, pose.position.x,
                                         pose.position.y, pose.position.z))
            ball_ready.set()
        if pose.name == 'iris_cam':
            drone_pose = (
                pose.position.x, pose.position.y, pose.position.z,
                pose.orientation.x, pose.orientation.y,
                pose.orientation.z, pose.orientation.w,
            )
            drone_pose_ready.set()


def rotate_vector(qx, qy, qz, qw, vx, vy, vz):
    """Rotate a vector by quaternion (x, y, z, w)."""
    # Quaternion rotation matrix times v.
    return (
        (1 - 2 * (qy * qy + qz * qz)) * vx
        + 2 * (qx * qy - qz * qw) * vy
        + 2 * (qx * qz + qy * qw) * vz,
        2 * (qx * qy + qz * qw) * vx
        + (1 - 2 * (qx * qx + qz * qz)) * vy
        + 2 * (qy * qz - qx * qw) * vz,
        2 * (qx * qz - qy * qw) * vx
        + 2 * (qy * qz + qx * qw) * vy
        + (1 - 2 * (qx * qx + qy * qy)) * vz,
    )


pose_topic = f'/world/{world}/dynamic_pose/info'
if not node.subscribe(Pose_V, pose_topic, on_poses):
    sys.exit(f'could not subscribe to {pose_topic}')
if camera_relative:
    if not drone_pose_ready.wait(timeout=3.0):
        sys.exit(f'no iris_cam pose received on {pose_topic}')
    px, py, pz, qx, qy, qz, qw = drone_pose
    # camera_link is 0.10 m along body +x and 0.02 m up. The Gazebo camera
    # sensor looks along that same +x axis. Use the horizontal projection so
    # small hover roll/pitch does not move the test arc off-centre.
    offset = rotate_vector(qx, qy, qz, qw, 0.10, 0.0, 0.02)
    forward = rotate_vector(qx, qy, qz, qw, 1.0, 0.0, 0.0)
    horizontal_norm = math.hypot(forward[0], forward[1])
    if horizontal_norm < 1e-6:
        sys.exit('camera forward axis is vertical; cannot construct test arc')
    fx, fy = forward[0] / horizontal_norm, forward[1] / horizontal_norm
    camera_x, camera_y, camera_z = px + offset[0], py + offset[1], pz + offset[2]
    # A small lateral offset means the drone must actually move to intercept;
    # the ball is not thrown directly at the hover point.
    x = camera_x + CAMERA_FORWARD_DISTANCE * fx + CAMERA_LATERAL_OFFSET * fy
    y = camera_y + CAMERA_FORWARD_DISTANCE * fy - CAMERA_LATERAL_OFFSET * fx
    z = camera_z + CAMERA_VERTICAL_OFFSET
    vel = [-BALL_TOWARD_SPEED * fx, -BALL_TOWARD_SPEED * fy, BALL_UP_SPEED]
    yaw_deg = math.degrees(math.atan2(fy, fx))
    print(f'live camera: ({camera_x:.2f}, {camera_y:.2f}, {camera_z:.2f}), '
          f'forward yaw {yaw_deg:.1f} deg')

    # Check the nominal level-hover view of the ascending arc through its
    # apex. The camera image is square, so horizontal and vertical FOV match.
    # A target approaching the camera can reach a still-higher image angle
    # after the apex; this check does not promise descent stays in frame.
    t_free_to_apex = BALL_UP_SPEED / GRAVITY
    forward_at_apex = (
        CAMERA_FORWARD_DISTANCE
        - 0.5 * BALL_TOWARD_SPEED * LAUNCH_DURATION
        - BALL_TOWARD_SPEED * t_free_to_apex
    )
    rise_at_apex = (
        CAMERA_VERTICAL_OFFSET
        + 0.5 * BALL_UP_SPEED * LAUNCH_DURATION
        + BALL_UP_SPEED ** 2 / (2.0 * GRAVITY)
    )
    apex_elevation = math.atan2(rise_at_apex, forward_at_apex)
    half_vertical_fov = 0.5 * CAMERA_VERTICAL_FOV
    if forward_at_apex <= 0.0 or apex_elevation >= half_vertical_fov:
        sys.exit(
            f'launch arc leaves camera FOV: apex elevation '
            f'{math.degrees(apex_elevation):.1f} deg, limit '
            f'{math.degrees(half_vertical_fov):.1f} deg'
        )
    print(f'ascending arc check: apex elevation '
          f'{math.degrees(apex_elevation):.1f} deg < camera half-FOV '
          f'{math.degrees(half_vertical_fov):.1f} deg')


def clear_persistent_wrench(name, entity_type):
    entity = Entity()
    entity.name = name
    entity.type = entity_type
    # Repetition plus a short delay makes cleanup robust even while Gazebo is
    # running below real time or transport discovery is still settling.
    for _ in range(3):
        clear_pub.publish(entity)
        time.sleep(0.05)


def wait_until_ball_pose(target, wall_timeout=20.0):
    deadline = time.monotonic() + wall_timeout
    while time.monotonic() < deadline:
        with pose_lock:
            if ball_samples and ball_samples[-1][0] >= target:
                return True
        time.sleep(0.01)
    return False


def wait_for_wrench_subscribers():
    deadline = time.monotonic() + 10.0
    while time.monotonic() < deadline:
        if persistent_pub.has_connections() and clear_pub.has_connections():
            return
        time.sleep(0.05)
    sys.exit('Gazebo wrench subscribers are missing; is ApplyLinkWrench loaded?')


def gazebo_service(path, request_type, request_text):
    # gz transport's Python Node.request can block its own subscription
    # callbacks during a slow service reply. A separate CLI client lets this
    # process keep receiving the ball pose from the instant it is created.
    command = [
        'gz', 'service', '-s', f'/world/{world}/{path}',
        '--reqtype', f'gz.msgs.{request_type}',
        '--reptype', 'gz.msgs.Boolean', '--timeout', '15000',
        '--req', request_text,
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True,
                                timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    answer = re.search(r'\bdata:\s*(true|false)\b', result.stdout)
    if result.returncode != 0:
        return None
    # Gazebo's remove/blocking CLI prints nothing if the entity is absent.
    if answer is None and path == 'remove/blocking':
        return False
    if answer is None:
        return None
    return answer.group(1) == 'true'


def spawn_ball():
    # A blocking remove avoids mistaking the old ball's pose for a new spawn.
    for _ in range(3):
        removed = gazebo_service('remove/blocking', 'Entity',
                                 'name: "drop_ball", type: MODEL')
        if removed is not None:
            break  # False means there was no old ball to remove.
        time.sleep(0.5)
    else:
        sys.exit('Gazebo did not acknowledge removal of the previous ball')
    with pose_lock:
        ball_samples.clear()
    ball_ready.clear()

    # Clear old persistent forces before creating a new entity with this name.
    clear_persistent_wrench('drop_ball', Entity.MODEL)
    clear_persistent_wrench('drop_ball::link', Entity.LINK)
    time.sleep(0.3)

    request = (f'sdf_filename: {json.dumps(sdf)}, name: "drop_ball", '
               f'pose: {{position: {{x: {x}, y: {y}, z: {z}}}}}')
    if gazebo_service('create/blocking', 'EntityFactory', request) is not True:
        sys.exit('Gazebo did not create a fresh drop_ball model')
    if not ball_ready.wait(timeout=5.0):
        sys.exit(f'new ball did not appear on {pose_topic}')


def verify_ballistic_coast(release_at):
    # Three samples after the force is cleared prove both launch velocity and
    # gravity-only parabolic flight. The first two estimate release velocity;
    # the last one checks the vertical acceleration independently.
    if not wait_until_ball_pose(release_at + 0.9):
        return False, 'no recent Gazebo ball pose after the launch'
    with pose_lock:
        samples = list(ball_samples)
    release_pose = min(samples, key=lambda p: abs(p[0] - release_at)) if samples else None
    expected_release = (x + 0.5 * vel[0] * LAUNCH_DURATION,
                        y + 0.5 * vel[1] * LAUNCH_DURATION,
                        z + 0.5 * vel[2] * LAUNCH_DURATION)
    if release_pose is None or math.dist(release_pose[1:], expected_release) > 0.25:
        actual = release_pose[1:] if release_pose else None
        return False, (f'actual release position {actual}, expected near '
                       f'{expected_release}; throw started too late')
    targets = [release_at + dt for dt in (0.12, 0.28, 0.8)]
    picked = [min(samples, key=lambda p: abs(p[0] - t)) for t in targets] if samples else []
    if len(picked) != 3 or any(abs(p[0] - t) > 0.12 for p, t in zip(picked, targets)):
        span = (f'{samples[0][0]:.2f}..{samples[-1][0]:.2f}'
                if samples else 'none')
        gaps = [round(abs(p[0] - t), 3) for p, t in zip(picked, targets)]
        return False, f'Gazebo pose sampling gap (span {span}, gaps {gaps})'
    p1, p2, p3 = picked
    dt12, dt23 = p2[0] - p1[0], p3[0] - p2[0]
    if dt12 < 0.05 or dt23 < 0.05:
        return False, 'Gazebo pose samples were too close together'
    vx = (p2[1] - p1[1]) / dt12
    vy = (p2[2] - p1[2]) / dt12
    vz12 = (p2[3] - p1[3]) / dt12
    vz23 = (p3[3] - p2[3]) / dt23
    vz_release = vz12 + GRAVITY * (0.5 * (p1[0] + p2[0]) - release_at)
    az = (vz23 - vz12) / (0.5 * (p2[0] + p3[0]) - 0.5 * (p1[0] + p2[0]))
    measured = (vx, vy, vz_release)
    errors = [abs(actual - target) for actual, target in zip(measured, vel)]
    limits = [max(0.8, 0.25 * abs(target)) for target in vel]
    if any(error > limit for error, limit in zip(errors, limits)):
        return False, f'actual release velocity {measured}, requested {tuple(vel)}'
    if abs(az + GRAVITY) > 3.0:
        return False, f'coasting vertical acceleration {az:.2f} m/s², not gravity'
    if vel[2] > 2.0 and p2[3] <= p1[3]:
        return False, 'ball did not rise after the launch force was cleared'
    peak = max((p for p in samples if release_at <= p[0] <= p3[0]),
               key=lambda p: p[3], default=None)
    if camera_relative and (peak is None or peak[3] <= p3[3] + 0.02):
        return False, 'full upward-then-downward arc was not observed'
    apex_text = (f'; observed apex z={peak[3]:.2f} m'
                 if peak is not None and peak[3] > p3[3] + 0.02 else '')
    return True, (f'Gazebo verified release at '
                  f'({release_pose[1]:.2f}, {release_pose[2]:.2f}, '
                  f'{release_pose[3]:.2f}) m; velocity '
                  f'({vx:.2f}, {vy:.2f}, {vz_release:.2f}) m/s; '
                  f'coast az={az:.2f} m/s²{apex_text}')


wait_for_wrench_subscribers()
force = EntityWrench()
force.entity.name = 'drop_ball'
force.entity.type = Entity.MODEL
force.wrench.force.x = MASS * vel[0] / LAUNCH_DURATION
force.wrench.force.y = MASS * vel[1] / LAUNCH_DURATION
force.wrench.force.z = MASS * (vel[2] / LAUNCH_DURATION + GRAVITY)

for attempt in (1, 2):
    spawn_ball()
    with pose_lock:
        launched_at = ball_samples[-1][0]
    if not persistent_pub.publish(force):
        sys.exit('Gazebo rejected the launch wrench publication')
    if not wait_until_ball_pose(launched_at + LAUNCH_DURATION):
        clear_persistent_wrench('drop_ball', Entity.MODEL)
        sys.exit('simulation stopped during launch; wrench cleared')
    with pose_lock:
        released_at = ball_samples[-1][0]
    clear_persistent_wrench('drop_ball', Entity.MODEL)
    success, report = verify_ballistic_coast(released_at)
    if success:
        print(f'ball launched from ({x:.2f}, {y:.2f}, {z:.2f}) '
              f'toward ({vel[0]:.2f}, {vel[1]:.2f}, {vel[2]:.2f}) m/s')
        print(report)
        break
    print(f'launch attempt {attempt} failed verification: {report}', file=sys.stderr)
else:
    sys.exit('ball launch failed twice; do not trust this run for interception')
