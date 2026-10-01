# plan_and_control

Solves for a one-shot intercept point + time for a drone to catch a
ballistic (thrown) object, given the object's filtered state from
`state_estimation` and the drone's own odometry. Re-solves on every new
object-state update rather than committing to a single plan, so the
intercept self-corrects as the estimate refines and the drone moves.

Two interchangeable solver nodes are provided, differing only in how they
model the drone's flight-time-to-target:

## `trajectory_predictor_ellipsoid`

Projects the drone's separate horizontal/vertical max acceleration and max
cruise speed onto the straight-line direction to the intercept point via an
ellipsoid projection, so the flight-time estimate matches a real quadrotor's
single shared-thrust-vector motion (as opposed to independently moving each
axis).

- Subscribes:
  - `/state_estimation/object_state` (`nav_msgs/Odometry`) — object position/velocity
  - `/fmu/out/vehicle_odometry` (subscribed as `nav_msgs/Odometry`) — drone's own position
- Publishes `/planning/intercept_ellipsoid` (`geometry_msgs/PoseStamped`)
- Parameters: `a_max_h`, `a_max_v`, `v_max_h`, `v_max_v`, `h_target`, `intercept_mode` (`ellipsoid` or `independent_axes` — switches which solver's result is published, though both are always computed for comparison logging)
- Solves the ballistic quadratic analytically for object impact time, then root-finds (`scipy.optimize.brentq`) the self-consistent intercept time where the drone's required flight time equals the elapsed time.
- The core math (`InterceptSolver`) has no ROS dependency and can be unit tested standalone.

## `trajectory_predictor_independent_axes`

Comparison/alternative model: each axis (x, y, z) has its own independent
max acceleration and max cruise speed, and the drone's time-to-target is the
*max* across axes (it hasn't "arrived" until every axis has finished). This
implies a staggered, non-straight-line path and is not representative of a
real quadrotor's actuation — it exists for side-by-side logging against the
ellipsoid model.

- Subscribes the same two topics as above.
- Publishes `/plan/intercept_timestamp_independent_axes` (`geometry_msgs/PoseStamped`).
- Parameters: `a_max_x`, `a_max_y`, `a_max_z`, `v_max_x`, `v_max_y`, `v_max_z`, `h_target`.

## Known issues

- **Broken build target:** `setup.py` registers a console script for
  `plan_and_control.trajectory_predictor_independent_axes`, but the source
  file in `plan_and_control/plan_and_control/` is currently named
  `trajectory_predictor_independent_axes` with no `.py` extension, so it
  won't be importable as that module. Rename it to
  `trajectory_predictor_independent_axes.py` before building.
- **Topic name mismatch:** both nodes subscribe to
  `/state_estimation/object_state`, but `state_estimation`'s
  `object_kalman_filter` actually publishes to `/estimation/object_state`.
- **Type mismatch on drone odometry:** both nodes subscribe to
  `/fmu/out/vehicle_odometry` as `nav_msgs/Odometry`, but PX4 actually
  publishes `px4_msgs/VehicleOdometry` on that topic (see
  `state_estimation`'s `px4_odom_to_tf`, which consumes the real type). As
  written, `drone_odom_callback` will never receive data — a bridge/adapter
  publishing `nav_msgs/Odometry` for the drone's own pose is needed first.
- Acceleration/velocity limit defaults are placeholders — see the `TODO` in
  each node's constructor to source them from PX4 `MPC_*` params or
  empirical step-response testing.

## Dependencies

- `rclpy`, `nav_msgs`, `geometry_msgs`
- `numpy`, `scipy`

## Build

```bash
cd ~/ros2_ws
colcon build --packages-select plan_and_control --symlink-install
```

## Running

```bash
source install/setup.bash
ros2 run plan_and_control trajectory_predictor_ellipsoid --ros-args -p intercept_mode:=ellipsoid
```
