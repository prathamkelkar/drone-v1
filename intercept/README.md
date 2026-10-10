# intercept

Flies the drone to the intercept point computed by `plan_and_control`, using
ArduPilot GUIDED mode through MAVROS. Fully automatic: set GUIDED → arm →
take off → hover until a target arrives → chase it.

## Node: `offboard_inercept_node`

(The executable name is spelled `offboard_inercept_node` in `setup.py`; the
ROS node name is `offboard_intercept_node`.)

**Subscribes**
| Topic | Type | Notes |
|---|---|---|
| `/planning/intercept_ellipsoid` | `geometry_msgs/PoseStamped` | Target, ENU `world`/`map`; non-finite targets are ignored |
| `/rotate_command` | `geometry_msgs/Vector3` | Only `z` (camera yaw offset, + = object to the right) is used |
| `/mavros/local_position/odom` | `nav_msgs/Odometry` | Position and yaw (best-effort) |
| `/mavros/state` | `mavros_msgs/State` | `connected`, `armed`, `mode` |

**Publishes**: `/mavros/setpoint_raw/local` (`mavros_msgs/PositionTarget`):
ENU values, `coordinate_frame = FRAME_LOCAL_NED` (MAVROS converts to NED),
position + yaw only (`type_mask` 2552, or 3576 when yaw is unknown).

**Services used**: `/mavros/set_mode` (`GUIDED`), `/mavros/cmd/arming`,
`/mavros/cmd/takeoff`. All calls are asynchronous, with retries and backoff.

**State machine** (one timer at `setpoint_rate`, sim time)

| State | Leaves when |
|---|---|
| `WAIT_CONNECT` | FCU connected and odometry received |
| `SET_GUIDED` | `/mavros/state` reports `GUIDED` |
| `ARM` | armed (rejections, e.g. EKF not ready, are retried with backoff) |
| `TAKEOFF` | takeoff accepted, or already airborne (> `airborne_height`) |
| `CLIMB` | within `takeoff_tolerance` of `takeoff_height` |
| `HOVER` | streams the hover setpoint; leaves when a target arrives |
| `TRACK` | streams the latest target (held until a new one) |
| `OVERRIDDEN` | entered from CLIMB/HOVER/TRACK if mode ≠ GUIDED or disarmed: publishes nothing; back to HOVER (or TAKEOFF on the ground) once GUIDED + armed |

Every startup step has `step_timeout`; on timeout the sequence restarts
(states already satisfied are skipped).

**Yaw**: setpoint = current yaw − `/rotate_command` yaw offset (ENU yaw is
counter-clockwise, the offset is positive to the right). Offsets older than
`rotate_command_timeout` count as zero, so the drone holds its heading when
the object is lost.

**Safety**: every setpoint is clamped to the `fence_min`/`fence_max` box
(map frame; z floor is also `min_target_height`) and clamping is logged;
non-finite setpoints are refused.

**Parameters**
| Name | Default | Meaning |
|---|---|---|
| `takeoff_height` | `4.0` | Hover height, m above home |
| `takeoff_tolerance` | `0.3` | Hover reached when within this, m |
| `min_target_height` | `0.3` | Lowest allowed setpoint, m |
| `airborne_height` | `0.5` | Above this, no takeoff command is sent |
| `setpoint_rate` | `20.0` | Hz |
| `step_timeout` | `60.0` | s per startup step |
| `retry_period` / `retry_backoff_max` | `2.0` / `10.0` | s |
| `service_timeout` | `5.0` | s to wait for a service response |
| `rotate_command_timeout` | `1.0` | s |
| `fence_min` / `fence_max` | `[-50,-50,0]` / `[50,50,20]` | Setpoint box, m |
| `odom_topic` | `/mavros/local_position/odom` | |

## Dependencies

- `rclpy`, `geometry_msgs`, `nav_msgs`, `mavros_msgs`

## Running

Normally started by `state_estimation`'s `full_pipeline.launch.py` (t=35 s).
To run it alone, with SITL, MAVROS and the rest of the pipeline up:

```bash
ros2 run intercept offboard_inercept_node --ros-args -p use_sim_time:=true
```

The node arms the drone and takes off on its own.

## Tests

```bash
python3 -m pytest intercept/test/test_setpoint_utils.py
```
