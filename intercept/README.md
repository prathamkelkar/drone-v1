# intercept

Offboard flight node that physically flies the drone to the intercept point
computed by `plan_and_control`. Runs a fully automatic mission: arm → climb
to hover height → hold position until a target arrives → chase it.

## Node: `offboard_inercept_node`

(The executable name is spelled `offboard_inercept_node` in `setup.py`; the
ROS node name is `offboard_intercept_node`.)

**Subscribes**
| Topic | Type | Notes |
|---|---|---|
| `/planning/intercept_ellipsoid` | `geometry_msgs/PoseStamped` | Target position, from `plan_and_control` |
| `/rotate_command` | `geometry_msgs/Vector3` | Only `z` (yaw offset) is used; from `state_estimation`'s `rotate_command` |
| `/fmu/out/vehicle_odometry` | `px4_msgs/VehicleOdometry` | Current position |
| `/fmu/out/vehicle_attitude` | `px4_msgs/VehicleAttitude` | Current yaw |

**Publishes** (`px4_msgs`, best-effort/volatile QoS)
| Topic | Type |
|---|---|
| `/fmu/in/offboard_control_mode` | `OffboardControlMode` (position control) |
| `/fmu/in/trajectory_setpoint` | `TrajectorySetpoint` |
| `/fmu/in/vehicle_command` | `VehicleCommand` |

**Behavior**
- A 20 Hz timer publishes the offboard heartbeat and a position setpoint
  continuously (PX4 needs ≥2 Hz or it rejects offboard mode).
- After 20 setpoint cycles it requests offboard mode and arming.
- Until the hover height is reached (within 0.3 m), the setpoint is the
  starting x/y at `z = -takeoff_height`. Once reached, it holds there until
  an intercept pose arrives, then commands that pose.
- Target height is clamped so the setpoint is never lower than
  `min_target_height` above ground. All positions are PX4 NED (z down).
- Commanded yaw = current yaw + `/rotate_command` yaw offset, keeping the
  object roughly centred in the camera.

**Parameters**
| Name | Default | Meaning |
|---|---|---|
| `takeoff_height` | `1.5` | Hover height in metres |
| `min_target_height` | `0.3` | Lowest allowed setpoint above ground, metres |

## Dependencies

- `rclpy`, `geometry_msgs`, `px4_msgs`
- `numpy`, `scipy`

## Build

```bash
cd ~/ros2_ws
colcon build --packages-select intercept --symlink-install
```

## Running

Normally started by `state_estimation`'s `full_pipeline.launch.py` (at
t=35 s). To run it alone, with PX4, the XRCE-DDS agent and the rest of the
pipeline up:

```bash
source install/setup.bash
ros2 run intercept offboard_inercept_node
```

The node arms the drone on its own — don't run it alongside `teleop_node`.

`package.xml` still has the placeholder description/license (TODO).
