# state_estimation

Turns raw PX4 telemetry and camera detections into world-frame poses/TF for
the rest of the stack: PX4 odometry → TF, 2D detection → 3D world pose, and a
Kalman filter that smooths that pose into a full position + velocity state.

## Nodes

### `px4_odom_to_tf`
Bridges PX4's internal odometry into a ROS TF transform.

- Subscribes `/fmu/out/vehicle_odometry` (`px4_msgs/VehicleOdometry`, best-effort/volatile QoS)
- Broadcasts a `world -> base_link` transform (via `tf2_ros.TransformBroadcaster`) using the message's position and quaternion.

### `object_localizer`
Converts a 2D detection + camera intrinsics into a 3D pose in the `world` frame, using a known real-world object width for monocular depth estimation.

- Subscribes `/camera/camera_info` (`sensor_msgs/CameraInfo`) for focal length / principal point, and `/detected_object` (`vision_msgs/Detection2D`) from `perception`.
- Assumes a known physical object width of `0.22` m (`KNOWN_OBJECT_WIDTH` in `object_localizer.py`) and back-projects `Z = fx * width / bbox_width` to recover depth, then `X`/`Y` from the pixel offset from the principal point.
- Waits for a `world -> camera_frame` transform to be available before processing a detection, then transforms the computed pose into `world`.
- Publishes `estimation/pose_object_raw` (`geometry_msgs/PoseStamped`).

### `object_kalman_filter`
A constant-velocity, gravity-gated Kalman filter (6-state: position + velocity) that smooths the raw localized pose into a full state estimate.

- Subscribes `/estimation/pose_object_raw` (`geometry_msgs/PoseStamped`).
- Gravity is only applied to the prediction step once downward velocity exceeds a threshold (`VZ_THRESHOLD = 0.3` m/s) — i.e. the object is assumed at rest until it's actually observed falling.
- Publishes `/estimation/object_state` (`nav_msgs/Odometry`) with position, velocity, and their covariances filled in; orientation and angular velocity are left as identity/zero (not meaningful for a tracked point-mass object).

### `rotate_to_keep_in_center.py` — **not built, work in progress**
A `Rotate` node intended to compute a pan/tilt correction to keep a detected object centered in frame. It is **not** registered as a console script in `setup.py` and is not referenced by any launch file, and as currently written it will fail if run:
- `create_publisher()` and `create_subscription(... self.camera_info_callback)` are both called without the required arguments (message type / QoS or callback).
- `rotate_callback` computes a `Vector3` and `return`s it instead of publishing it.

Leave this file alone until it's finished — it isn't part of the running pipeline.

## Launch file: `launch/full_pipeline.launch.py`

Brings up the full simulation + perception + state estimation pipeline in one command, staged with delays so each stage's dependencies are up before it starts:

1. **Immediately:** Micro XRCE-DDS Agent, MAVProxy, and PX4 SITL (`make px4_sitl gz_x500_depth` in `~/PX4-Autopilot`, overridable via the `px4_dir` launch argument).
2. **At t=15s:** ROS↔Gazebo bridges for `/clock`, camera image, and camera info (remapped to `/camera/image_raw` and `/camera/camera_info`).
3. **At t=20s:** a static `base_link -> camera_link` transform, and `px4_odom_to_tf`.
4. **At t=25s:** `perception_node` (launched in its own terminal via `gnome-terminal`, since it needs to run from the workspace root to find `yolo11n.pt`), `object_localizer`, and `object_kalman_filter`.

```bash
ros2 launch state_estimation full_pipeline.launch.py
# or, to point at a PX4-Autopilot checkout elsewhere:
ros2 launch state_estimation full_pipeline.launch.py px4_dir:=/path/to/PX4-Autopilot
```

Requires `gnome-terminal` to be installed (used to spawn the perception node in its own window). PX4 world/model target is fixed to `gz_x500_depth`.

## Known cross-package inconsistency

`plan_and_control`'s trajectory predictors subscribe to `/state_estimation/object_state`,
but the topic actually published here is `/estimation/object_state`. Rename one
side to match before wiring the two packages together end-to-end.

## Dependencies

- `rclpy`, `sensor_msgs`, `vision_msgs`, `geometry_msgs`, `nav_msgs`
- `tf2_ros`, `tf2_geometry_msgs`
- `px4_msgs`
- `numpy`

## Build

```bash
cd ~/ros2_ws
colcon build --packages-select state_estimation --symlink-install
```
