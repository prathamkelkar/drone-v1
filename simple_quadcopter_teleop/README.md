# simple_quadcopter_teleop

Keyboard teleop node for manually flying a PX4-simulated quadcopter over
offboard velocity setpoints, plus a standalone robot description asset for a
simple quadcopter model.

## Node: `teleop_node`

Reads single keypresses from stdin (non-blocking, raw terminal mode) and
streams velocity setpoints to PX4 via `px4_msgs`, in PX4's NED world frame.

**Publishes**
| Topic | Type |
|---|---|
| `/fmu/in/offboard_control_mode` | `px4_msgs/OffboardControlMode` |
| `/fmu/in/trajectory_setpoint` | `px4_msgs/TrajectorySetpoint` |
| `/fmu/in/vehicle_command` | `px4_msgs/VehicleCommand` |

**Subscribes**
| Topic | Type |
|---|---|
| `/fmu/out/vehicle_status_v4` | `px4_msgs/VehicleStatus` |

All topics use best-effort/volatile QoS, as required by PX4's uXRCE-DDS bridge.

A 20 Hz timer (`0.05s`) continuously publishes the offboard heartbeat and
current velocity setpoint — PX4 requires this stream at ≥2 Hz or it will
reject/exit offboard mode.

**Controls**

| Key | Action |
|---|---|
| `w` / `s` | Forward / backward |
| `a` / `d` | Left / right |
| `i` / `k` | Up / down |
| `j` / `l` | Yaw left / right |
| `space` | Stop (zero velocity/yaw rate) |
| `r` | Arm + switch to offboard mode |
| `q` | Quit |

Speed is fixed at `0.2` m/s and yaw rate at `0.5` rad/s per keypress
(`self.speed`, `self.yaw_speed` in `teleop_node.py`).

Wait a couple of seconds after the node starts before pressing `r` — PX4
needs a steady stream of setpoints already flowing before it will accept the
offboard mode switch.

## `description/sample.urdf.xacro`

A xacro robot description for a simple X-quad frame (4 arms + motors, base,
IMU, depth camera) with Gazebo Classic-style plugins (`libgazebo_ros_*`,
`imu_sensor`, `depth_camera`, and a custom `gazebo_ros_simple_quad`
force/torque-driven plugin). This is a standalone asset — it is **not**
currently referenced by `launch/full_pipeline.launch.py` or any other launch
file in this workspace, which instead uses PX4's own `gz_x500_depth` model
in Gazebo (Harmonic) SITL.

## Dependencies

- `rclpy`, `px4_msgs`
- Standard library: `termios`, `tty`, `select` (Linux-only, needed for raw
  keyboard input)

## Build

```bash
cd ~/ros2_ws
colcon build --packages-select simple_quadcopter_teleop --symlink-install
```

## Running

See the top-level [README.md](../../README.md) for the full PX4 + Gazebo
SITL setup this node depends on. Once that's running:

```bash
source install/setup.bash
ros2 run simple_quadcopter_teleop teleop_node
```

Click into the terminal running the node so it has keyboard focus before
pressing any keys.
