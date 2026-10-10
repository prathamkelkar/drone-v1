# perception

YOLO-based single-object detector node. Runs an Ultralytics YOLO model over the
incoming camera feed and publishes the single highest-confidence detection of
the tracked class (parameter `target_class`) as a `vision_msgs/Detection2D`.
It only depends on `/camera/image_raw`, so it is camera-agnostic.

## Node: `perception_without_nn` (default in the launch file)

HSV colour-threshold detector for the orange test ball (`drop_ball`,
`glide_ball.py`), no neural network: threshold (`hsv_lower` / `hsv_upper`,
default `[5,150,100]`..`[25,255,255]`) on a downscaled frame (`scale` 0.5),
morphological clean-up, then the largest round-enough blob (`min_area_px`,
`min_fill`) is published on `/detected_object` as class `ball`, with its
enclosing circle as the bounding box. `publish_debug: true` publishes the mask
on `/perception/debug_mask`. Note the static `target_ball` in
`drone_world.sdf` is pure red (hue 0), outside the default hue range.

## Node: `perception_node`

**Subscribes**
| Topic | Type | QoS |
|---|---|---|
| `/camera/image_raw` | `sensor_msgs/Image` | Best-effort, volatile, depth 1 |

**Publishes**
| Topic | Type | QoS |
|---|---|---|
| `/detected_object` | `vision_msgs/Detection2D` | Best-effort, volatile, depth 1 |

**Behavior**
- Parameters: `model_path` (default `~/ros2_ws/best.pt`, a yolo11n
  fine-tuned on `ball`, `carton`, `plastic_bottle`; absolute, so any cwd
  works), `device` (`cuda:0` or `cpu`; falls back to CPU without CUDA, set
  by the launch argument `perception_device`), `target_class` (default
  `plastic_bottle`, must be one of the model's classes).
- On every incoming frame, runs inference and keeps only the detection with
  the highest confidence among boxes above `confidence_threshold` (`0.25`,
  hardcoded) **and** of class `target_class`. The class filter exists because
  the drone's own propellers appear in frame and get misclassified.
- If nothing qualifies, no message is published for that frame.
- The published `Detection2D` carries one `ObjectHypothesisWithPose` (class
  name + confidence) and a pixel-space bounding box (`bbox.center`,
  `size_x`, `size_y`). 3D pose is *not* filled in here — that's done
  downstream by `state_estimation`'s `object_localizer`.

## Dependencies

- `rclpy`, `sensor_msgs`, `vision_msgs`
- `cv_bridge` (OpenCV image conversion)
- `ultralytics` (YOLO), `torch`: `pip install --user --break-system-packages ultralytics`
- `numpy` (1.x, for `cv_bridge`)

## Running

```bash
source ~/ros2_ws/install/setup.bash
ros2 run perception perception_node --ros-args -p device:=cpu
```

Normally started by `state_estimation`'s `full_pipeline.launch.py`.

## Build

```bash
cd ~/ros2_ws
colcon build --packages-select perception --symlink-install
```
