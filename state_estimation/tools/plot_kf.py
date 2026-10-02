#!/usr/bin/env python3
"""Record raw detections vs Kalman filter output, then plot them.

Usage: plot_kf.py [--duration SECONDS] [--save FILE.png]

Raw     : /estimation/pose_object_raw  (geometry_msgs/PoseStamped, world/NED)
Filtered: /estimation/object_state     (nav_msgs/Odometry, world/NED)

Records for --duration seconds (or until Ctrl-C), then shows a plot of
x, y, z (position) and the filter's velocity estimate. Both topics are
best-effort, so this uses best-effort QoS (rqt_plot's default reliable
subscription would never connect). Times are sim time, from the node clock
at receipt. World frame is PX4 NED, so z is plotted as height (-z) to read
naturally: a thrown ball rises then falls.
"""
import argparse
import time

import matplotlib.pyplot as plt
import rclpy
from geometry_msgs.msg import PoseStamped
from nav_msgs.msg import Odometry
from rclpy.parameter import Parameter
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

ap = argparse.ArgumentParser()
ap.add_argument('--duration', type=float, default=30.0)
ap.add_argument('--save', default=None)
ap.add_argument('--wall-time', action='store_true', help='use wall clock instead of /clock (sim not running)')
args = ap.parse_args()

rclpy.init()
node = rclpy.create_node('plot_kf', parameter_overrides=[Parameter('use_sim_time', value=not args.wall_time)])
qos = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT, durability=DurabilityPolicy.VOLATILE,
                 history=HistoryPolicy.KEEP_LAST, depth=50)

raw = []   # (t, x, y, z)
kf = []    # (t, x, y, z, vx, vy, vz)


def now():
    return node.get_clock().now().nanoseconds * 1e-9


def on_raw(m):
    p = m.pose.position
    raw.append((now(), p.x, p.y, p.z))


def on_kf(m):
    p, v = m.pose.pose.position, m.twist.twist.linear
    kf.append((now(), p.x, p.y, p.z, v.x, v.y, v.z))


node.create_subscription(PoseStamped, '/estimation/pose_object_raw', on_raw, qos)
node.create_subscription(Odometry, '/estimation/object_state', on_kf, qos)

print(f'Recording for {args.duration:.0f} s (Ctrl-C to stop early)...')
t_end = time.monotonic() + args.duration  # wall-clock bound so it can never hang
try:
    while rclpy.ok() and time.monotonic() < t_end:
        rclpy.spin_once(node, timeout_sec=0.1)
except KeyboardInterrupt:
    pass
node.destroy_node()
rclpy.shutdown()

if not raw and not kf:
    raise SystemExit('No data received. Is the pipeline running and the object detected?')

t0 = min([r[0] for r in raw[:1]] + [k[0] for k in kf[:1]])
fig, axes = plt.subplots(4, 1, sharex=True, figsize=(10, 9))
labels = ['x (north) [m]', 'y (east) [m]', 'height = -z [m]']
sign = [1, 1, -1]
for i, ax in enumerate(axes[:3]):
    if raw:
        ax.plot([r[0] - t0 for r in raw], [sign[i] * r[1 + i] for r in raw],
                'o', ms=4, alpha=0.6, label='raw detection')
    if kf:
        ax.plot([k[0] - t0 for k in kf], [sign[i] * k[1 + i] for k in kf],
                '-o', lw=2, ms=5, label='Kalman filter')
    ax.set_ylabel(labels[i])
    ax.grid(alpha=0.3)
axes[0].legend(loc='best')
if kf:
    axes[3].plot([k[0] - t0 for k in kf], [-k[6] for k in kf], label='KF vertical speed (up +)')
    axes[3].plot([k[0] - t0 for k in kf], [k[4] for k in kf], label='KF vx', alpha=0.6)
    axes[3].plot([k[0] - t0 for k in kf], [k[5] for k in kf], label='KF vy', alpha=0.6)
    axes[3].legend(loc='best')
axes[3].set_ylabel('velocity [m/s]')
axes[3].set_xlabel('sim time [s]')
axes[3].grid(alpha=0.3)
fig.suptitle('Raw detection vs Kalman filter')
fig.tight_layout()
if args.save:
    fig.savefig(args.save, dpi=130)
    print(f'saved {args.save}')
plt.show()
