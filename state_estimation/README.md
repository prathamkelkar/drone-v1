# state_estimation

Turns MAVROS odometry and camera detections into world-frame poses/TF for
the rest of the stack: odometry → TF, 2D detection → 3D world pose, and a
Kalman filter that smooths that pose into a full position + velocity state.
All frames are ENU (world/map) / FLU (base_link); `camera_link` is an optical
frame (x right, y down, z forward).

## Nodes

### `odom_to_tf`
Publishes `map -> base_link` from MAVROS odometry (MAVROS's own TF is off).

- Subscribes `/mavros/local_position/odom` (`nav_msgs/Odometry`, best-effort, depth 1; topic is the `odom_topic` parameter).
- Copies position and quaternion unchanged; stamps with the node clock (sim time), not the message stamp.

### `mavros_setup`
One-shot helper started by the launch file. Waits for MAVROS and the FCU,
sets `/mavros/local_position` `tf.send` to `false`, and requests MAVLink
message intervals 30/31/32 (ATTITUDE, ATTITUDE_QUATERNION, LOCAL_POSITION_NED)
at 30 Hz via `/mavros/set_message_interval`, retrying until each succeeds,
then exits. Parameters: `message_ids`, `message_rate`, `disable_mavros_tf`,
`retry_period`, `timeout` (wall seconds).

### `object_localizer`
Converts a 2D detection + camera intrinsics into a 3D pose in the `world` frame, using a known real-world object width for monocular depth estimation.

- Subscribes `/camera/camera_info` and `/detected_object` (`vision_msgs/Detection2D`) from `perception`.
- Assumes a physical object width of `0.22` m (`KNOWN_OBJECT_WIDTH`) and back-projects `Z = fx * width / bbox_width`, then `X`/`Y` from the pixel offset.
- Transforms the pose into `world` using TF at the image capture time (`use_image_stamp`, default true), falling back to the latest TF.
- Publishes `estimation/pose_object_raw` (`geometry_msgs/PoseStamped`).

### `object_kalman_filter`
A constant-velocity, gravity-gated Kalman filter (6-state: position + velocity).
The math is in `kalman_filter.py` (pure numpy, unit-tested in `test/test_kalman_gravity.py`).

- Subscribes `/estimation/pose_object_raw`; publishes `/estimation/object_state` (`nav_msgs/Odometry`) with position, velocity and covariances.
- Parameter `gravity`: positive magnitude (default 9.81; the launch file uses 0.0 for the constant-velocity test). It is applied as a **−z** acceleration (ENU), and only after the object is seen falling (`vz < −0.3` m/s).

### `rotate_command`
Computes the camera-relative yaw/pitch angle to the detected object: `angle = atan((pixel - principal_point) / focal_length)`.

- Publishes `/rotate_command` (`geometry_msgs/Vector3`, best-effort): `z` = yaw, positive = object right of centre; `y` = pitch, positive = below centre.
- The `intercept` node turns that into an ENU yaw setpoint (right = clockwise = negative yaw).

## Launch file: `launch/full_pipeline.launch.py`

Starts Gazebo (`drone_world.sdf`), MAVROS, the bridges and the whole pipeline,
staged with delays (constants `T_*` at the top of the file). ArduPilot SITL is
**not** started by it; see the top-level README.

| t (s) | Started |
|---|---|
| 0 | `gz sim` |
| 10 | `ros_gz_bridge` (`/clock`, `/camera/image` → `/camera/image_raw`, `/camera/camera_info`), MAVROS (`mavros_node` with the stock ArduPilot config + `config/mavros_overrides.yaml`) |
| 20 | `mavros_setup`, static TFs `world -> map` and `base_link -> camera_link`, `odom_to_tf` |
| 25 | `perception_node`, `object_localizer`, `object_kalman_filter` |
| 30 | `trajectory_predictor_ellipsoid`, `rotate_command` |
| 35 | `offboard_inercept_node` (GUIDED, arm, takeoff, intercept) |

Arguments: `world`, `fcu_url` (default `udp://:14550@`), `perception_device` (`cuda:0`/`cpu`).

## Gazebo models (`models/`)

- `ardupilot/iris_cam`, `ardupilot/worlds/drone_world.sdf` (world name `iris_runway`): the ArduPilot iris with a forward camera.
- `drop_ball.sdf`, `plastic_bottle.sdf` and the spawner scripts `launch_ball.py`, `glide_ball.py`, `glide_bottle.py` (Gazebo transport; `WORLD` env var selects the world, default `iris_runway`).

## Tools

- `tools/plot_kf.py`: records raw detections vs. filter output and plots x, y, z (ENU) and velocity.

## Dependencies

- `rclpy`, `rcl_interfaces`, `sensor_msgs`, `vision_msgs`, `geometry_msgs`, `nav_msgs`, `mavros_msgs`
- `tf2_ros`, `tf2_geometry_msgs`, `numpy`
- Launch: `mavros`, `ros_gz_bridge`, `perception`, `plan_and_control`, `intercept`

## Build / test

```bash
colcon build --packages-select state_estimation
python3 -m pytest state_estimation/test/test_kalman_gravity.py
```
