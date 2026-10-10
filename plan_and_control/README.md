# plan_and_control

Solves for a one-shot intercept point + time for a drone to catch a
ballistic (thrown) object, given the object's filtered state from
`state_estimation` and the drone's own odometry. Re-solves on every new
object-state update rather than committing to a single plan, so the
intercept self-corrects as the estimate refines and the drone moves.

All inputs and outputs are ENU (z up). The object state is in `world`, the
drone odometry in `map` (identity transform between them). `h_target` is the
intercept height above home (MAVROS's local origin), so it should equal the
interceptor's `takeoff_height`.

## `trajectory_predictor_ellipsoid`

Projects the drone's separate horizontal/vertical max acceleration and max
cruise speed onto the straight-line direction to the intercept point via an
ellipsoid projection, so the flight-time estimate matches a real quadrotor's
single shared-thrust-vector motion.

- Subscribes:
  - `/estimation/object_state` (`nav_msgs/Odometry`): object position/velocity
  - `/mavros/local_position/odom` (`nav_msgs/Odometry`, best-effort; parameter `drone_odom_topic`): drone position (only position is used)
- Publishes `/planning/intercept_ellipsoid` (`geometry_msgs/PoseStamped`, ENU, header copied from the object state)
- Parameters: `a_max_h`, `a_max_v`, `v_max_h`, `v_max_v`, `h_target`, `object_model` (`ballistic`, `constant_velocity` or `static`), `intercept_mode` (`ellipsoid` or `independent_axes`: which solver's result is published; both are computed for comparison logging)
- Solves the ballistic quadratic analytically for the time the object reaches `h_target`, then root-finds (`scipy.optimize.brentq`) the self-consistent intercept time.
- The core math (`InterceptSolver`) has no ROS dependency.

## `trajectory_predictor_independent_axes`

Comparison model: each axis has its own max acceleration and cruise speed,
and the drone's time-to-target is the max across axes. Not started by the
launch file.

- Subscribes `/estimation/object_state` and `/mavros/local_position/odom` (both best-effort).
- Publishes `/plan/intercept_timestamp_independent_axes` (`geometry_msgs/PoseStamped`).
- Parameters: `a_max_x`, `a_max_y`, `a_max_z`, `v_max_x`, `v_max_y`, `v_max_z`, `h_target`, `drone_odom_topic`.

## Known issues

- Acceleration/velocity limit defaults are placeholders. See the `TODO` in
  each node's constructor to source them from ArduPilot parameters
  (`WPNAV_ACCEL`, `WPNAV_SPEED`, `WPNAV_SPEED_UP/DN`, ...) or empirical
  step-response testing.

## Dependencies

- `rclpy`, `nav_msgs`, `geometry_msgs`, `numpy`, `scipy`

## Running

```bash
ros2 run plan_and_control trajectory_predictor_ellipsoid --ros-args -p intercept_mode:=ellipsoid -p h_target:=4.0
```

Normally started by `state_estimation`'s `full_pipeline.launch.py` (with
`object_model: constant_velocity`, `h_target: 4.0`, `intercept_mode: independent_axes`).
