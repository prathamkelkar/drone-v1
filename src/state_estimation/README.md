# state_estimation

Turns MAVROS odometry and camera detections into world-frame poses/TF for
the rest of the stack: odometry → TF, 2D detection → 3D world pose, and a
Kalman filter that smooths that pose into a full position + velocity state.
All frames are ENU (world/map) / FLU (base_link); `camera_link` (left) and
`camera_right_link` are optical frames (x right, y down, z forward).

## Nodes

### `odom_to_tf`
Publishes `map -> base_link` from MAVROS odometry (MAVROS's own TF is off).

- Subscribes `/mavros/local_position/odom` (`nav_msgs/Odometry`, best-effort, depth 1; topic is the `odom_topic` parameter).
- Copies position and quaternion unchanged; stamps with the node clock (sim time), not the message stamp.

### `mavros_setup`
One-shot helper started by the launch file. Waits for MAVROS and the FCU,
sets `/mavros/local_position` `tf.send` to `false`, and requests MAVLink
message intervals 30/31/32 (ATTITUDE, ATTITUDE_QUATERNION, LOCAL_POSITION_NED)
at the configured rate (100 Hz in `full_pipeline.launch.py`) via
`/mavros/set_message_interval`, retrying until each succeeds,
then exits. Parameters: `message_ids`, `message_rate`, `disable_mavros_tf`,
`retry_period`, `timeout` (wall seconds).

### `object_localizer`
Converts a 2D detection + camera intrinsics into a 3D pose in the `world` frame, using a known real-world object width for monocular depth estimation.

- Subscribes `/camera/camera_info` and `/detected_object` (`vision_msgs/Detection2D`) from `perception`.
- Assumes a physical object width of `0.22` m (`KNOWN_OBJECT_WIDTH`) and back-projects `Z = fx * width / bbox_width`, then `X`/`Y` from the pixel offset.
- Transforms the pose into `world` using TF at the image capture time (`use_image_stamp`, default true), falling back to the latest TF.
- Publishes `estimation/pose_object_raw` (`geometry_msgs/PoseStamped`).

### `object_kalman_filter`
A constant-velocity / ballistic Kalman filter (6-state: position + velocity).
The math is in `kalman_filter.py` (pure numpy, unit-tested in `test/test_kalman_gravity.py`).

- Subscribes `/estimation/pose_object_raw`; publishes `/estimation/object_state` (`nav_msgs/Odometry`) with position, velocity and covariances.
- Parameter `gravity`: positive magnitude (default 9.81; the launch file sets 0.0 or 9.81 from its `motion` argument). It is applied as a **−z** acceleration (ENU).
- Parameter `gravity_gate` (default `false`): `false` applies gravity from the first detection (object already in free flight); `true` only once the object is seen falling (`vz < −0.3` m/s), for objects that start at rest.
- `extended_kalman_filter.py`: work in progress (quadratic-drag EKF), not installed as an executable.

### `rotate_command`
Computes the camera-relative yaw/pitch angle to the detected object: `angle = atan((pixel - principal_point) / focal_length)`.

- Publishes `/rotate_command` (`geometry_msgs/Vector3`, best-effort): `z` = yaw, positive = object right of centre; `y` = pitch, positive = below centre.
- The `intercept` node turns that into an ENU yaw setpoint (right = clockwise = negative yaw).

## Launch file: `launch/full_pipeline.launch.py`

Starts Gazebo (`drone_world_stereo.sdf` on this branch), MAVROS, the bridges
and the whole pipeline,
staged with delays (constants `T_*` at the top of the file). ArduPilot SITL is
**not** started by it; see the top-level README.

| t (s) | Started |
|---|---|
| 0 | `gz sim` |
| 10 | `ros_gz_bridge` (`/clock`, left `/camera/image` → `/camera/image_raw` and `/camera/camera_info`, right `/stereo/right/image` → `/stereo/right/image_raw` and `/stereo/right/camera_info`), MAVROS (`mavros_node` with the stock ArduPilot config + `config/mavros_overrides.yaml`) |
| 20 | `mavros_setup`, static TFs `world -> map`, `base_link -> camera_link`, `base_link -> camera_right_link`, `odom_to_tf` |
| 25 | `perception_without_nn` or `perception_node`, `object_localizer`, `object_kalman_filter` |
| 30 | `trajectory_predictor_ellipsoid`, `rotate_command` |
| 35 | `offboard_inercept_node` (GUIDED, arm, takeoff, intercept) |

Arguments: `world`, `fcu_url` (default `udp://:14550@`), `perception` (`hsv`/`yolo`), `motion` (`linear`/`ballistic`: Kalman filter gravity 0/9.81 and the predictor's object model), `perception_device` (`cuda:0`/`cpu`), `target_class` (`ball`/`carton`/`plastic_bottle`), `yolo_model`.

The drone limits shared by the predictor and the interceptor (`A_MAX_*`,
`V_MAX_*`, `TILT_DELAY`) are constants at the top of the file and must stay
within the ArduPilot limits in `scripts/intercept.parm`. The simulated camera
Iris is 1.77 kg with two 0.01 kg cameras; mass is documented but is not an input to the
acceleration-based solver.

## Gazebo models (`models/`)

- `ardupilot/iris_stereo`, `ardupilot/worlds/drone_world_stereo.sdf` (world name `iris_runway`): this branch's default. Two parallel forward monocular RGB cameras at body `(0.10, +0.06, 0.02)` m (left) and `(0.10, -0.06, 0.02)` m (right), with a 0.12 m baseline, 640×640 images, identical 1.412 rad horizontal FOV and 30 Hz requested update rates. The left camera retains `/camera/image_raw` and `/camera/camera_info` for the existing HSV/YOLO and monocular localizer; the right camera has independent `/stereo/right/image_raw` and `/stereo/right/camera_info`. Both have optical TF frames. The world keeps the `iris_cam` entity name so the ball/recording tools still find the drone.
- `ardupilot/iris_stereo_with_ardupilot` and `ardupilot/iris_stereo_with_standoffs`: full project-owned copies of the ArduPilot Iris SDFs and meshes from `ardupilot_gazebo` commit `082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5`. Their model and mesh URIs point only to these copies; the external checkout is not edited. See `ardupilot/ARDUPILOT_GAZEBO_LICENSE.md`.
- `ardupilot/iris_cam`, `ardupilot/worlds/drone_world.sdf`: preserved single-camera model and world. The `ardupilot` branch still defaults to these; this branch defaults to the stereo world. Both worlds retain the flat light-grey background, neutral ground, and no static orange target.
- `drop_ball.sdf` (orange, for the HSV detector), `plastic_bottle.sdf` and the spawner scripts `launch_ball.py` (no arguments places the ball 5.2 m in front of the live `iris_cam`, 0.3 m to its right, at camera height; a 0.2 s simulated force pulse launches it toward the camera at 3.5 m/s and up at 5.5 m/s; the launcher checks the nominal ascending camera FOV, then verifies actual Gazebo release position, velocity, and gravity-only parabolic coast from pose timestamps, retrying once if the force was missed; `X Y Z V0` kicks straight up at an absolute position; `X Y Z VX VY VZ` throws in any absolute direction), `glide_ball.py`, `glide_bottle.py` (Gazebo transport; `WORLD` env var selects the world, default `iris_runway`).

Two camera streams do **not** yet produce stereo depth. `object_localizer.py`
still uses known object width; no perception, localizer, Kalman filter or
intercept logic was changed for this branch. Calibrated intrinsics/extrinsics,
left-right time synchronization, correspondence/disparity and stereo 3-D
localization are separate future work.

## Tools

- `tools/plot_kf.py`: records raw detections vs. filter output and plots x, y, z (ENU) and velocity.
- `tools/intercept_check.py`: closest approach between `iris_cam` and the object, from Gazebo's own poses (start it before spawning the object).
- `tools/spectate.py`: three spectator cameras plus the drone's camera in one window, recorded to an mp4 in slow motion.

## Dependencies

- `rclpy`, `rcl_interfaces`, `sensor_msgs`, `vision_msgs`, `geometry_msgs`, `nav_msgs`, `mavros_msgs`
- `tf2_ros`, `tf2_geometry_msgs`, `numpy`
- Launch: `mavros`, `ros_gz_bridge`, `perception`, `plan_and_control`, `intercept`

## Build / test

```bash
colcon build --packages-select state_estimation
python3 -m pytest src/state_estimation/test/test_kalman_gravity.py
```
