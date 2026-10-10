# intercept

Flies the drone to the intercept point computed by `plan_and_control`, using
ArduPilot GUIDED mode through MAVROS. Fully automatic: set GUIDED → arm →
take off → hover until a target arrives → chase it → stop, hold, fly home,
wait for the next one.

## Node: `offboard_inercept_node`

(The executable name is spelled `offboard_inercept_node` in `setup.py`; the
ROS node name is `offboard_intercept_node`.)

**Subscribes**
| Topic | Type | Notes |
|---|---|---|
| `/planning/intercept_ellipsoid` | `geometry_msgs/PoseStamped` | Target, ENU `world`/`map`; non-finite targets are ignored |
| `/rotate_command` | `geometry_msgs/Vector3` | Only `z` (camera yaw offset, + = object to the right) is used |
| `/mavros/local_position/odom` | `nav_msgs/Odometry` | Position and yaw (best-effort) |
| `/mavros/local_position/velocity_local` | `geometry_msgs/TwistStamped` | ENU velocity (best-effort) |
| `/mavros/state` | `mavros_msgs/State` | `connected`, `armed`, `mode` |

**Publishes**: `/mavros/setpoint_raw/local` (`mavros_msgs/PositionTarget`):
ENU values, `coordinate_frame = FRAME_LOCAL_NED` (MAVROS converts to NED),
always with yaw (when known). One of: position (`type_mask` 2552), velocity
(+ acceleration feedforward), or acceleration only (2111; ArduCopter 4.1+).
The FORCE bit is never set.

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
| `INTERCEPT` | runs intercept attempts (below) around the hover point |
| `OVERRIDDEN` | entered from CLIMB/INTERCEPT if mode ≠ GUIDED or disarmed: publishes nothing; back to INTERCEPT at the current position (or TAKEOFF on the ground) once GUIDED + armed |

Every startup step has `step_timeout`; on timeout the sequence restarts
(states already satisfied are skipped).

**Intercept attempts** (`sequencer.InterceptSequencer`, one at a time)

| State | Setpoint | Leaves when |
|---|---|---|
| `READY` | hover point (position) | a new target stream starts after `rearm_quiet` s without targets |
| `CHASE` | see `chase_mode` | point passed (within `pass_radius`), no target for `target_timeout` s after its arrival time, `max_chase_time`, or `max_chase_distance` from home |
| `STOP` | velocity 0 + braking feedforward `a_brake` | slower than 0.3 m/s |
| `HOLD` | position where it stopped | `hold_time` s |
| `RETURN` | gentle velocity flight home (`return_speed`, `return_accel`) | home and stopped |

`chase_mode`:
- `thrust` (default): every cycle, the constant acceleration that takes the
  drone from its current position and velocity to the predictor's point
  exactly at the point's stamped arrival time
  (`thrust_control.timed_intercept_accel`, with `tilt_delay`), sent as an
  acceleration-only setpoint. Capped by ArduPilot's lean angle
  (`ATC_ANGLE_MAX`).
- `velocity`: full-speed velocity setpoint toward the point plus full
  acceleration feedforward (`sequencer.chase_command`). Shaped by ArduPilot
  at `WP_ACC`, so keep `a_max_h` ≤ `WP_ACC`.

In both, the drone reaches the point at full speed or still accelerating; it
is trying to hit the object there, not stop there.

**ArduPilot limits**: `scripts/intercept.parm` (loaded by
`scripts/start_sitl.sh`) raises the lean angle, `WP_*` speed/acceleration
and `PSC_*_JERK` limits and sets `GUID_OPTIONS` bit 4 (no horizontal position
stabilization in velocity/acceleration targets). The node's `a_max_*` /
`v_max_*` must stay within them.

**Yaw**: setpoint = current yaw − `/rotate_command` yaw offset (ENU yaw is
counter-clockwise, the offset is positive to the right). Offsets older than
`rotate_command_timeout` count as zero, so the drone holds its heading when
the object is lost.

**Safety**: position setpoints and targets are clamped to the
`fence_min`/`fence_max` box (map frame; z floor is also `min_target_height`)
and clamping is logged; non-finite setpoints are refused. Velocity and
acceleration chases are bounded by `max_chase_distance` / `max_chase_time`,
and below `min_safe_height` the acceleration is never downward.

**Parameters**
| Name | Default | Meaning |
|---|---|---|
| `takeoff_height` | `4.0` | Hover height, m above home |
| `takeoff_tolerance` | `0.3` | Hover reached when within this, m |
| `min_target_height` | `0.3` | Lowest allowed setpoint, m |
| `airborne_height` | `0.5` | Above this, no takeoff command is sent |
| `setpoint_rate` | `100.0` | Hz (the thrust guidance re-plans every cycle) |
| `step_timeout` | `60.0` | s per startup step |
| `retry_period` / `retry_backoff_max` | `2.0` / `10.0` | s |
| `service_timeout` | `5.0` | s to wait for a service response |
| `rotate_command_timeout` | `1.0` | s |
| `fence_min` / `fence_max` | `[-50,-50,0]` / `[50,50,20]` | Setpoint box, m |
| `odom_topic` | `/mavros/local_position/odom` | |
| `velocity_topic` | `/mavros/local_position/velocity_local` | |
| `chase_mode` | `thrust` | `thrust` or `velocity` |
| `v_max_h` / `v_max_up` / `v_max_dn` | `12` / `6` / `4` | m/s, velocity mode |
| `a_max_h` / `a_max_up` / `a_max_dn` | `9.8` / `4.5` / `5.0` | m/s², guidance and feedforward limits |
| `a_brake` | `8.0` | m/s², stopping after the chase |
| `response_lag` | `0.15` | s, braking-curve lead (flight home) |
| `tilt_delay` | `0.25` | s before a commanded acceleration takes effect; = predictor's `tilt_delay` |
| `terminal_time` / `end_margin` | `0.15` / `0.15` | s, final push through the point |
| `min_safe_height` | `0.3` | m |
| `pass_radius` | `1.0` | m |
| `target_timeout` / `max_chase_time` / `max_chase_distance` | `0.5` / `4.0` / `6.0` | s / s / m |
| `hold_time` / `rearm_quiet` | `2.0` / `1.0` | s |
| `return_speed` / `return_accel` | `2.0` / `2.0` | m/s, m/s² |

The launch file overrides most of these (see `full_pipeline.launch.py`).

## Dependencies

- `rclpy`, `geometry_msgs`, `nav_msgs`, `mavros_msgs`, `numpy`

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
python3 intercept/test/sim_intercept_compare.py   # offline old-vs-new chase comparison (generic quad model)
```
