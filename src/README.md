# drone-v1: object intercept drone (ArduPilot SITL + Gazebo + ROS 2)

A quadcopter that detects a thrown or falling object, predicts its trajectory
and flies to intercept it.

```
/camera/image_raw -> perception_without_nn (HSV) or perception_node (YOLO)
  -> object_localizer (2D -> 3D via TF)
  -> object_kalman_filter -> trajectory_predictor_ellipsoid -> offboard_inercept_node
  -> MAVROS (/mavros/setpoint_raw/local) -> ArduPilot (GUIDED)
```

Stack: ROS 2 Jazzy, Gazebo Harmonic, ArduPilot SITL (ArduCopter, `iris_cam`
model with a forward camera), MAVROS. All frames are ROS-standard ENU (world)
/ FLU (body). TF chain: `world -> map` (identity, static) `-> base_link`
(`odom_to_tf`, from `/mavros/local_position/odom`) `-> camera_link` (static,
optical frame).

| Package | Contents |
|---|---|
| `perception` | detectors: HSV colour blob (`perception_without_nn`, default) and YOLO (`perception_node`) |
| `state_estimation` | `odom_to_tf`, `object_localizer`, `object_kalman_filter`, `rotate_command`, `mavros_setup`, the Gazebo models/world and `full_pipeline.launch.py` |
| `plan_and_control` | intercept-point solvers |
| `intercept` | flies the drone in GUIDED mode via MAVROS |

## Prerequisites

- Ubuntu 24.04 (WSL2 works), ROS 2 Jazzy, Gazebo Harmonic
- `ros-jazzy-mavros` (+ `mavros_extras`), `ros-jazzy-ros-gz-bridge`, `ros-jazzy-vision-msgs`, `ros-jazzy-cv-bridge`
- ArduPilot at `~/ardupilot` with its Python venv at `~/venv-ardupilot`, and
  [ardupilot_gazebo](https://github.com/ArduPilot/ardupilot_gazebo) built at `~/ardupilot_gazebo`
- `pip install --user --break-system-packages ultralytics` (keep system numpy < 2 for `cv_bridge`)

Gazebo must find the models (in `~/.bashrc`):

```bash
export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:$GZ_SIM_SYSTEM_PLUGIN_PATH
export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:$GZ_SIM_RESOURCE_PATH
export GZ_SIM_RESOURCE_PATH=$HOME/ros_ardupilot_ws/src/state_estimation/models/ardupilot:$GZ_SIM_RESOURCE_PATH
```

## Build

Use **system** Python for colcon and every ROS terminal (never the ArduPilot venv).

```bash
cd ~/ros_ardupilot_ws
source /opt/ros/jazzy/setup.bash
colcon build
source install/setup.bash
```

(Building at the repo root with `colcon build` also works; `build/`,
`install/`, `log/` are git-ignored.)

## One-time SITL parameters

In the MAVProxy prompt of a first SITL run:

```
param set FRAME_CLASS 1
param set FRAME_TYPE 1
reboot
```

## Running

1. **T1, Gazebo.** Started by the launch file in step 3; no separate terminal needed.
   (To run it by hand: `gz sim -v4 -r src/state_estimation/models/ardupilot/worlds/drone_world.sdf`.)
2. **T2, ArduPilot SITL** (needs the venv and an interactive MAVProxy prompt,
   so it is never started by the launch file):
   ```bash
   cd ~/ros_ardupilot_ws
   src/scripts/start_sitl.sh
   # = source ~/venv-ardupilot/bin/activate && cd ~/ardupilot/ArduCopter && \
   #   sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON --console --out 127.0.0.1:14550 \
   #     --add-param-file=src/scripts/intercept.parm
   ```
   `scripts/intercept.parm` raises ArduPilot's lean angle, speed,
   acceleration and jerk limits for the interceptor (see `intercept/README.md`).
3. **T3, the pipeline:**
   ```bash
   cd ~/ros_ardupilot_ws
   source /opt/ros/jazzy/setup.bash
   source install/setup.bash
   ros2 launch state_estimation full_pipeline.launch.py perception_device:=cpu
   ```
   Launch arguments: `world` (SDF path), `fcu_url` (default `udp://:14550@`;
   real drone `/dev/ttyAMA0:921600`), `perception_device` (`cuda:0` or `cpu`),
   `perception` (`hsv`, default: orange ball, or `yolo`), `motion` (`linear`,
   default, for `glide_*.py`; `ballistic` for `launch_ball.py`: sets the
   Kalman filter gravity and the predictor's object model together),
   `target_class` (`ball`, `carton` or `plastic_bottle`; default `plastic_bottle`)
   and `yolo_model` (default `~/ros_ardupilot_ws/src/best.pt`), both only for
   `perception:=yolo`.
   Stage delays are the `T_*` constants at the top of the launch file (the
   sim runs at ~36% real time, so they are generous).
4. **Flight.** The interceptor (started at t≈35 s) sets GUIDED, arms, takes off to
   4 m and hovers by itself. If you run without it, use the MAVProxy prompt
   (`STABILIZE>` / `GUIDED>`):
   ```
   mode guided
   arm throttle
   takeoff 4
   ```

`mavros_setup` (started by the launch) turns MAVROS's own TF off and requests
ATTITUDE / ATTITUDE_QUATERNION / LOCAL_POSITION_NED at 100 Hz; without it
odometry arrives at ~2.7 Hz. It retries until MAVROS and the FCU are up, so
SITL may be started before or after the launch.

5. **A target.** The world contains no built-in orange target: spawn exactly
   one test object after the drone is hovering. Use `motion:=linear` with
   `glide_ball.py`, or restart the launch with `motion:=ballistic` before using
   `launch_ball.py`. With no arguments, the launcher reads the drone's current
   Gazebo pose and places the ball 5.2 m ahead, 0.3 m to the camera's right,
   at camera height. A 0.2 s simulated launch pulse accelerates it toward
   3.5 m/s toward the drone and 5.5 m/s up; after the pulse it follows a
   gravity-only parabola. The ascending arc through its apex remains inside
   the nominal level-hover camera FOV. The planner's configured ArduPilot
   limits yield a feasible intercept even if the drone begins to move 0.6 s
   after the pulse (idealized straight-line model, not a flight guarantee).
   The launcher checks actual Gazebo pose samples and retries once if the
   force was missed; only a
   `Gazebo verified release at ... coast az=...` line means the throw
   succeeded. It uses the live camera heading, so drone yaw can change:

   ```bash
   cd ~/ros_ardupilot_ws
   source /opt/ros/jazzy/setup.bash
   /usr/bin/python3 src/state_estimation/models/launch_ball.py
   ```

## Ballistic intercept test and recording

Start the pipeline in ballistic mode:

```bash
cd ~/ros_ardupilot_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
ros2 launch state_estimation full_pipeline.launch.py \
  perception:=hsv motion:=ballistic perception_device:=cpu
```

After the drone is hovering, create a fresh output directory. In every
recorder terminal, run the common setup below and then start one recorder
**before** spawning the ball:

```bash
cd ~/ros_ardupilot_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
mkdir -p test_runs/run_01

# Run one of the following in each terminal:

# Gazebo ground-truth closest approach (prints HIT/MISS and saves a plot)
/usr/bin/python3 src/state_estimation/tools/intercept_check.py \
  --object drop_ball --duration 20 \
  --save test_runs/run_01/intercept_result.png

# Raw localisation versus Kalman-filter output
/usr/bin/python3 src/state_estimation/tools/plot_kf.py \
  --duration 20 --save test_runs/run_01/kf_output.png

# Four-camera MP4; q or Ctrl-C finalises the file
/usr/bin/python3 src/state_estimation/tools/spectate.py \
  --out test_runs/run_01/intercept.mp4 --rate 10 --slowmo 2
```

For a replayable numeric log, start this in another ROS-sourced terminal:

```bash
cd ~/ros_ardupilot_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
ros2 bag record -o test_runs/run_01/kf_bag --topics \
  /clock /detected_object /estimation/pose_object_raw \
  /estimation/object_state /planning/intercept_ellipsoid \
  /mavros/local_position/odom /mavros/local_position/velocity_local
```

Stop the bag with Ctrl-C. Use a new `run_XX` directory for each attempt.

Once the recorders say they are ready, launch the ball from a separate
terminal. Do not pass fixed coordinates: the no-argument mode reads the live
`iris_cam` pose and builds the arc in front of its current heading.

```bash
cd ~/ros_ardupilot_ws
source /opt/ros/jazzy/setup.bash
/usr/bin/python3 src/state_estimation/models/launch_ball.py
```

## Quick checks

```bash
ros2 topic echo /mavros/state --once                 # connected: true, mode, armed
ros2 param get /mavros/local_position tf.send        # false
ros2 run tf2_ros tf2_echo world camera_link          # z ~ 4.2 m in hover
ros2 run tf2_tools view_frames                       # one tree, one map->base_link publisher
ros2 topic hz /mavros/local_position/odom            # ~30 Hz (sim time)
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Gazebo world loads without the drone | `GZ_SIM_RESOURCE_PATH` misses `src/state_estimation/models/ardupilot` or `ardupilot_gazebo/models` |
| SITL stuck at "waiting for JSON" | Gazebo not running / `GZ_SIM_SYSTEM_PLUGIN_PATH` misses `ardupilot_gazebo/build` |
| `/mavros/state` `connected: false` | SITL not started with `--out 127.0.0.1:14550` |
| Arming rejected repeatedly | EKF still initialising (wait), or pre-arm failure: see the MAVProxy console |
| Odometry ~2.7 Hz | `mavros_setup` failed (check its log) |
| `cv_bridge` / numpy errors | numpy 2 installed in `~/.local`; ROS needs numpy 1.x |
