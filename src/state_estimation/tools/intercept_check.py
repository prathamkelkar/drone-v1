#!/usr/bin/env python3
"""Measure how close the drone got to the target object, from Gazebo's own poses.

Usage: intercept_check.py [--object NAME] [--duration S] [--save FILE.png]
       defaults: object drop_ball (glide_ball.py / launch_ball.py); use
       glide_bottle for glide_bottle.py.  WORLD env var selects the world
       (default iris_runway = ardupilot/worlds/drone_world.sdf).

Start it before spawning the object. It records the true positions of the
drone (iris_cam) and the object from /world/<world>/dynamic_pose/info
until --duration seconds pass or Ctrl-C, then prints the closest approach
and plots 3D distance, vertical separation, and the x-y top view.

"Hit" means the bodies touched: centre distance below HIT_DISTANCE, the
drone's reach from its centre (~0.25 m to the iris's motors + ~0.12 m
propeller ~= 0.38 m) plus the 0.11 m ball radius. That's generous (the drone isn't a
sphere), so check the closest-approach distance too.
"""
import argparse
import os
import threading
import time

import numpy as np
from gz.msgs10.pose_v_pb2 import Pose_V
from gz.transport13 import Node

HIT_DISTANCE = 0.49  # m

ap = argparse.ArgumentParser()
ap.add_argument('--object', default='drop_ball')
ap.add_argument('--drone', default='iris_cam')
ap.add_argument('--duration', type=float, default=20.0)
ap.add_argument('--save', default=None)
args = ap.parse_args()
world = os.environ.get('WORLD', 'iris_runway')

lock = threading.Lock()
samples = []   # (sim time s, drone xyz, object xyz)


def on_poses(msg: Pose_V):
    found = {}
    for p in msg.pose:
        if p.name in (args.drone, args.object):
            found[p.name] = (p.position.x, p.position.y, p.position.z)
    if len(found) == 2:
        t = msg.header.stamp.sec + msg.header.stamp.nsec * 1e-9
        with lock:
            samples.append((t, found[args.drone], found[args.object]))


node = Node()
topic = f'/world/{world}/dynamic_pose/info'
if not node.subscribe(Pose_V, topic, on_poses):
    raise SystemExit(f'could not subscribe to {topic}')
print(f'Watching {args.drone} and {args.object} for {args.duration:.0f} s (Ctrl-C to stop early)...')
try:
    time.sleep(args.duration)
except KeyboardInterrupt:
    pass

with lock:
    data = list(samples)
if not data:
    raise SystemExit(f'No samples with both {args.drone!r} and {args.object!r}. '
                     'Was the object spawned while this was running? Right --object name?')

t = np.array([d[0] for d in data])
drone = np.array([d[1] for d in data])
obj = np.array([d[2] for d in data])
dist = np.linalg.norm(drone - obj, axis=1)
horizontal_gap = np.linalg.norm(drone[:, :2] - obj[:, :2], axis=1)
vertical_gap = np.abs(drone[:, 2] - obj[:, 2])
i = int(np.argmin(dist))
t0 = t[0]
print(f'closest approach: {dist[i]:.2f} m at t = {t[i] - t0:.2f} s after the object appeared')
print(f'  separation: {horizontal_gap[i]:.2f} m horizontal, {vertical_gap[i]:.2f} m vertical')
print(f'  drone  at ({drone[i][0]:.2f}, {drone[i][1]:.2f}, {drone[i][2]:.2f})')
print(f'  object at ({obj[i][0]:.2f}, {obj[i][1]:.2f}, {obj[i][2]:.2f})   (Gazebo frame: x east, y north, z up)')
print('HIT' if dist[i] < HIT_DISTANCE else 'MISS',
      f'(hit = centres closer than {HIT_DISTANCE} m)')

import matplotlib.pyplot as plt  # noqa: E402  (only needed once there's data)

elapsed = t - t0
fig, axes = plt.subplots(3, 1, figsize=(10, 10))
axes[0].plot(t - t0, dist)
axes[0].axhline(HIT_DISTANCE, color='r', ls='--', label=f'hit threshold {HIT_DISTANCE} m')
axes[0].axvline(t[i] - t0, color='k', ls=':', label=f'closest {dist[i]:.2f} m')
axes[0].set_xlabel('sim time since object appeared [s]')
axes[0].set_ylabel('drone-object distance [m]')
axes[0].legend()
axes[0].grid(alpha=0.3)

# Gazebo uses z-up. Plot both true heights and their absolute separation so
# a small x-y gap cannot hide a vertical miss.
axes[1].plot(elapsed, drone[:, 2], label='drone height')
axes[1].plot(elapsed, obj[:, 2], label='object height')
axes[1].plot(elapsed, vertical_gap, '--', label='vertical gap |Δz|')
axes[1].axvline(elapsed[i], color='k', ls=':',
                label=f'closest: vertical gap {vertical_gap[i]:.2f} m')
axes[1].set_xlabel('sim time since object appeared [s]')
axes[1].set_ylabel('z / vertical distance [m]')
axes[1].legend()
axes[1].grid(alpha=0.3)
axes[1].set_title('vertical comparison (Gazebo z-up)')

axes[2].plot(drone[:, 0], drone[:, 1], label='drone')
axes[2].plot(obj[:, 0], obj[:, 1], label='object')
axes[2].plot(*drone[i][:2], 'ko')
axes[2].plot(*obj[i][:2], 'ko')
axes[2].set_xlabel('x east [m]')
axes[2].set_ylabel('y north [m]')
axes[2].set_aspect('equal', adjustable='datalim')
axes[2].legend()
axes[2].grid(alpha=0.3)
axes[2].set_title('top view (black dots: positions at closest 3D approach)')
fig.tight_layout()
if args.save:
    fig.savefig(args.save, dpi=130)
    print(f'saved {args.save}')
plt.show()
