# perception

YOLO-based single-object detector node. Runs an Ultralytics YOLO model over the
incoming camera feed and publishes the single highest-confidence detection of
the tracked class (`sports ball`) as a `vision_msgs/Detection2D`.

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
- Loads the model from `yolo11n.pt` using a path relative to the process's
  current working directory — run the node from the directory that contains
  that file (the workspace root, `~/ros2_ws`, in this repo).
- On every incoming frame, runs inference and keeps only the detection with
  the highest confidence among boxes above `confidence_threshold` (`0.25`)
  **and** of class `target_class` (`'sports ball'`). Both are hardcoded in
  `perception_node.py`. The class filter exists because the drone's own
  propellers appear in frame and get classified as e.g. "airplane".
- If nothing qualifies, no message is published for that frame.
- The published `Detection2D` carries one `ObjectHypothesisWithPose` (class
  name + confidence) and a pixel-space bounding box (`bbox.center`,
  `size_x`, `size_y`). 3D pose is *not* filled in here — that's done
  downstream by `state_estimation`'s `object_localizer`.

## Dependencies

- `rclpy`, `sensor_msgs`, `vision_msgs`
- `cv_bridge` (OpenCV image conversion)
- `ultralytics` (YOLO) — `pip install ultralytics`
- `numpy`

## Running

```bash
cd ~/ros2_ws
source install/setup.bash
ros2 run perception perception_node
```

Run from `~/ros2_ws` so the `yolo11n.pt` weights file next to it can be
found; otherwise model loading will fail. (The full-pipeline launch file
opens a `gnome-terminal` that does not `cd` first, so if the model fails to
load there, start the node manually from `~/ros2_ws`.)

## Build

```bash
cd ~/ros2_ws
colcon build --packages-select perception --symlink-install
```
