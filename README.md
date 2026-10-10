# drone-v1

A ROS 2 workspace for a PX4-simulated quadcopter that detects a thrown
object with YOLO, localizes and filters its 3D trajectory, and (eventually)
autonomously intercepts it — plus a manual keyboard teleop mode for flying
the drone directly.

## Packages

| Package | Purpose | README |
|---|---|---|
| `perception` | YOLO object detection over the camera feed | [src/perception](src/perception/README.md) |
| `state_estimation` | PX4 odom → TF, 2D detection → 3D world pose, Kalman filter, full-pipeline launch file | [src/state_estimation](src/state_estimation/README.md) |
| `plan_and_control` | Ballistic intercept solvers (two flight-time models) | [src/plan_and_control](src/plan_and_control/README.md) |
| `intercept` | Offboard node: arms, takes off to hover, then chases the target intercept pose | [src/intercept](src/intercept/README.md) |
| `simple_quadcopter_teleop` | Manual keyboard offboard-velocity teleop | [src/simple_quadcopter_teleop](src/simple_quadcopter_teleop/README.md) |
| `px4_msgs` | PX4 ROS 2 message/service definitions (external, cloned in — see [its README](src/px4_msgs/README.md)) | — |

See each package's README for its nodes, topics, and package-specific
caveats. One known issue remains (the independent-axes predictor in
`plan_and_control` has stale topic names/types); it isn't part of the launch
file, but see that README before using it.

## Prerequisites

- Ubuntu 24.04
- ROS 2 Jazzy
- Gazebo Sim (Harmonic, `gz sim` v8.x)
- PX4-Autopilot (built for the `gz_x500` / `gz_x500_depth` simulation targets)
- Python 3.12+
- Python packages: `ultralytics` (YOLO), `numpy`, `scipy`, plus the usual
  ROS 2 Python deps (`cv_bridge`, `vision_msgs`, `tf2_ros`,
  `tf2_geometry_msgs`) — install `vision_msgs` and `cv_bridge` via your ROS 2
  distro's package manager (e.g. `sudo apt install ros-jazzy-vision-msgs
  ros-jazzy-cv-bridge`), and `ultralytics`/`scipy` via `pip`.

## Installation

### 1. Clone PX4-Autopilot (if not already present)

```bash
cd ~
git clone https://github.com/PX4/PX4-Autopilot.git --recursive
cd PX4-Autopilot
bash ./Tools/setup/ubuntu.sh
```

### 2. Set the Gazebo resource path

PX4's models and worlds must be discoverable by Gazebo. Add this to your `~/.bashrc`:

```bash
echo 'export GZ_SIM_RESOURCE_PATH=$HOME/PX4-Autopilot/Tools/simulation/gz/models:$HOME/PX4-Autopilot/Tools/simulation/gz/worlds:$GZ_SIM_RESOURCE_PATH' >> ~/.bashrc
source ~/.bashrc
```

### 3. Install the Micro XRCE-DDS Agent

This bridges PX4's internal messaging (uORB) to ROS 2 topics (`/fmu/...`). Without it, no PX4 topics will be visible to ROS 2.

```bash
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent
mkdir build && cd build
cmake ..
make
sudo make install
sudo ldconfig /usr/local/lib/
```

### 4. Install MAVProxy (lightweight ground control station)

PX4 requires an active GCS/MAVLink connection to pass preflight checks and allow arming. MAVProxy satisfies this without needing a full GUI application like QGroundControl.

```bash
pip install --user MAVProxy --break-system-packages
```

### 5. Set up your ROS 2 workspace

Clone `px4_msgs` into your workspace (must match your PX4-Autopilot version):

```bash
cd ~/ros2_ws/src
git clone https://github.com/PX4/px4_msgs.git
```

Clone or place this repo's packages (`perception`, `state_estimation`, `plan_and_control`, `intercept`, `simple_quadcopter_teleop`) into `~/ros2_ws/src` as well.

Build everything:

```bash
cd ~/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

### 6. (Optional) GPU offload — for hybrid graphics laptops (e.g. Intel + Nvidia)

If your Gazebo GUI runs sluggishly on integrated graphics, force it onto your discrete GPU:

```bash
echo 'export __GLX_VENDOR_LIBRARY_NAME=nvidia' >> ~/.bashrc
echo 'export __NV_PRIME_RENDER_OFFLOAD=1' >> ~/.bashrc
source ~/.bashrc
```

## Running

There are two ways to run this: the full sensing/estimation pipeline
(`state_estimation`'s launch file), or manual teleop only. Both need the
same PX4 + Gazebo + XRCE-DDS + MAVProxy stack underneath.

### Option A — Full pipeline (perception → estimation → planning → intercept)

```bash
cd ~/ros2_ws
source install/setup.bash
ros2 launch state_estimation full_pipeline.launch.py
```

This single command starts the Micro XRCE-DDS Agent, MAVProxy, PX4 SITL
(`gz_x500_depth`), the Gazebo↔ROS bridges for clock/image/camera-info, a
static camera TF, `px4_odom_to_tf`, `perception_without_nn` (colour-threshold
ball detector; the YOLO `perception_node` is still in the package but not
launched) (in its own terminal —
requires `gnome-terminal`), `object_localizer`, `object_kalman_filter`,
`rotate_command`, `trajectory_predictor_ellipsoid` and the `intercept`
package's offboard node (`offboard_inercept_node`), staged with delays
(15 s → 35 s) so each stage's dependencies are up first.

The intercept node flies fully automatically: arm → climb to
`takeoff_height` (4.0 m) → hold until a target arrives → chase it. Wait for
`Hover height reached` in its log before spawning an object.

The object's motion model is one launch argument, which sets the Kalman
filter's `gravity`, the predictor's `object_model` and the interceptor's
`object_gravity` together (a mismatch makes the pipeline chase a ball it
thinks is falling):

```bash
ros2 launch state_estimation full_pipeline.launch.py                    # motion:=linear (default): glide_ball.py
ros2 launch state_estimation full_pipeline.launch.py motion:=ballistic  # launch_ball.py (thrown / dropped)
```

Perception is `perception_without_nn` (orange-ball colour detector).

See [state_estimation's README](src/state_estimation/README.md) and
[plan_and_control's README](src/plan_and_control/README.md) for topic
details.

### Complete parabolic interception test - working

Use this workflow for a thrown ball. The launch command **must** include
`motion:=ballistic`: the default is `motion:=linear`, which disables gravity
in both the Kalman filter and predictor and can produce impossible intercept
points above the ball's real trajectory.

Open five terminals and run the commands below in order. The first command
also creates one folder for all plots and recordings.

**Terminal 1 — launch the complete pipeline with the ballistic model:**

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
mkdir -p ~/ros2_ws/results
ros2 launch state_estimation full_pipeline.launch.py motion:=ballistic
```

Wait until the interceptor reports `Hover height reached` / `READY (home)`
before continuing.

**Terminal 2 — record raw detections and the Kalman-filter estimate:**

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
python3 ~/ros2_ws/src/state_estimation/tools/plot_kf.py \
  --duration 20 \
  --save ~/ros2_ws/results/parabolic_kf.png
```

This graph compares raw and filtered north/east/height measurements and the
KF velocity estimate.

**Terminal 3 — record true closest approach and vertical separation:**

```bash
source /opt/ros/jazzy/setup.bash
source ~/ros2_ws/install/setup.bash
python3 ~/ros2_ws/src/state_estimation/tools/intercept_check.py \
  --duration 20 \
  --save ~/ros2_ws/results/parabolic_intercept.png
```

This graph uses Gazebo's true poses. It plots total 3D distance, drone and
ball height, vertical gap, and the top view. It prints `HIT` if the centres
come within 0.49 m.

**Terminal 4 — record side/front/top/onboard video:**

```bash
python3 ~/ros2_ws/src/state_estimation/tools/spectate.py \
  --out ~/ros2_ws/results/parabolic_run.mp4 \
  --slowmo 3 \
  --rate 10
```

The lower 10 Hz spectator-camera rate reduces rendering load on the
simulation. Use `--slowmo 1` for real-time playback or `--no-window` to
record without displaying the combined camera view.

**Terminal 5 — launch the test ball only after Terminals 2–4 are ready:**

```bash
python3 ~/ros2_ws/src/state_estimation/models/launch_ball.py \
  1.5 -0.75 3.5 \
  0.0 0.5 6.5
```

The arguments are `X Y Z VX VY VZ` in Gazebo coordinates: x east/forward,
y north and z up. This test starts 1.5 m forward and 0.75 m south at 3.5 m,
then moves north at 0.5 m/s and upward at 6.5 m/s. Its theoretical peak is
about 5.65 m. `launch_ball.py X Y Z V0` is the shorter form for a purely
vertical kick.

Let the two graph tools finish their 20 s capture. Press `q` in the spectator
window or Ctrl-C in Terminal 4 to finalize the MP4; do not force-kill it while
it is writing. The resulting artifacts are:

```text
~/ros2_ws/results/parabolic_kf.png
~/ros2_ws/results/parabolic_intercept.png
~/ros2_ws/results/parabolic_run.mp4
```

Change the filenames before another attempt if the previous results should
be kept. Rerunning `launch_ball.py` removes the previous ball first.

`launch_ball.py` uses Gazebo's ApplyLinkWrench system, which PX4's
`gz_bridge/server.config` already loads. Do not add it as a `<plugin>` in the
world SDF: declaring world plugins prevents the `server.config` systems from
loading. Also in the model folder is `glide_ball.py`, a constant-velocity
ball intended for a pipeline launched with `motion:=linear`.

`spectate.py` removes its three extra cameras on exit unless `--keep` is
supplied.

### Drone speed limits and how the chase is commanded

The launch file sets PX4's offboard limits to the drone's maximum at startup
with `PX4_PARAM_*` environment variables (PX4 applies them as `param set`):

| PX4 parameter | PX4 default | Launch value | Why |
|---|---|---|---|
| `MPC_XY_VEL_MAX` | 12 m/s | 20 m/s | parameter maximum |
| `MPC_Z_VEL_MAX_UP` | 3 m/s | 8 m/s | parameter maximum |
| `MPC_Z_VEL_MAX_DN` | 1.5 m/s | 4 m/s | parameter maximum |
| `MPC_TILTMAX_AIR` | 45° | 52° | steepest tilt at which full thrust still holds altitude (52.4°) → 12.6 m/s² horizontal |
| `MPC_THR_MAX` | 1.0 | 1.0 | full thrust |

Physical limits of the simulated x500 (from its Gazebo model): 2.13 kg,
34.2 N maximum thrust (thrust/weight 1.64), 6.3 m/s² climb, about 7.9 m/s²
descent, 12.6 m/s² horizontal at 52° tilt. `MPC_ACC_HOR_MAX` and
`MPC_ACC_UP_MAX` are not used in offboard mode.

The full-pipeline launch uses `chase_mode` `thrust`. The interceptor waits
for a feasible point on `/planning/intercept_ellipsoid`, then uses our own
intercept guidance in `intercept/thrust_control.py`, sent to PX4 as an
acceleration setpoint (`TrajectorySetpoint.acceleration`) at 100 Hz; PX4's
own fast loops turn it into tilt and thrust:

- target selection: the predictor applies its ballistic model, feasibility
  limits, and 0.3 m minimum interception height before publishing a point;
  it first propagates the timestamped Kalman state through perception latency
  to the current sim time, and includes the 0.1 s tilt delay in reachability;
  the message timestamp is when the object is predicted to reach that point
- guidance: every cycle, from the drone's current position and velocity,
  calculate the acceleration that reaches the latest point at its stamped
  arrival time, allowing `tilt_delay` (0.1 s) for PX4 to tilt; commands beyond
  the drone's limits are scaled to the maximum feasible effort
- end: do not declare the point lost or passed before its arrival time; keep
  pushing through for `end_margin` (0.15 s), then brake, hold and return home

The launch file also raises PX4's attitude gain (`MC_ROLL_P`/`MC_PITCH_P`
4.0 → 6.5) and rate limits (`MC_ROLLRATE_MAX`/`MC_PITCHRATE_MAX` 220 → 480°/s)
so the drone tilts faster. `test/sim_intercept_compare.py` (in the
`intercept` package) is the offline simulation used to tune `tilt_delay`.

The goal is to *hit* the object, not to stop at a point: in every mode the
drone reaches the intercept point at full speed or still accelerating, and
only brakes once it is past it (hit or miss, the attempt is over then).

`chase_mode` `velocity` (alternative): each cycle it sends a full-speed
velocity setpoint toward the predictor's point (capped by `v_max_h` 20 /
`v_max_up` 8 / `v_max_dn` 4 m/s) plus full acceleration feedforward
(`a_max_h` 12.6, `a_max_up` 6.3, `a_max_dn` 7.9 m/s²) while below that speed,
which PX4 adds to its own velocity feedback - no braking curve. The chase ends
once the point is behind the drone (within `pass_radius`, 1 m). (A `position`
mode that sent the point as a position setpoint was removed: PX4 slows down
when approaching a position setpoint, so it always arrived late.)

Each attempt has a defined end (logged as `Intercept: <STATE> (<reason>)`):
`READY` (hovering at home) → `CHASE` when a new target appears → it stops
chasing after the intercept point is passed, when no new intercept point
arrives for `target_timeout` (0.5 s),
after `max_chase_time` (4 s) or beyond `max_chase_distance` (6 m) from home
→ `STOP` (brakes at `a_brake`, 12.6 m/s²) → `HOLD` for `hold_time` (2 s) →
`RETURN` home at `return_speed` (2 m/s, the only flight that slows to stop at
a point) → `READY`. A new attempt only starts once targets have been absent
for `rearm_quiet` (1 s), so the old object can't restart a chase. The drone
only yaws toward the object while detections are fresh; otherwise it holds
its heading.
The predictor's `a_max_h` 12.6, `v_max_h` 20, `a_max_v` 6.3, `v_max_v` 4 match
these limits (its single vertical limit uses the smaller of climb and
descent).

### Option B — Manual teleop only

Open four terminals.

**Terminal 1 — Micro XRCE-DDS Agent:**
```bash
MicroXRCEAgent udp4 -p 8888
```

**Terminal 2 — MAVProxy (fake GCS):**
```bash
mavproxy.py --master=udp:127.0.0.1:14550
```

**Terminal 3 — PX4 + Gazebo:**
```bash
cd ~/PX4-Autopilot
make px4_sitl gz_x500
```
Wait for the `pxh>` prompt and the Gazebo window with the drone visible. Click into the Gazebo window and press **Escape** to unlock free camera control (PX4 starts the camera in follow-mode by default).

Verify PX4 is ready to arm:
```
pxh> commander check
```
This should show no "No connection to the GCS" failure (MAVProxy resolves this).

**Terminal 4 — Teleop node:**
```bash
cd ~/ros2_ws
source install/setup.bash
ros2 run simple_quadcopter_teleop teleop_node
```

## Controls

Click into Terminal 4 so it has keyboard focus, then:

| Key | Action |
|-----|--------|
| `w` / `s` | Forward / backward |
| `a` / `d` | Left / right |
| `i` / `k` | Up / down |
| `j` / `l` | Yaw left / right |
| `space` | Stop (zero velocity) |
| `r` | Arm + switch to offboard mode |
| `q` | Quit |

**Note:** Wait a couple of seconds after launching the node before pressing `r` — PX4 requires a steady stream of setpoints flowing before it will accept an offboard mode switch.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Publisher count: 0` on `/fmu/...` topics | PX4/Gazebo not running, or `MicroXRCEAgent` not started |
| `Unknown topic` on a `/fmu/...` topic | Topic name version mismatch (e.g. `_v1` vs `_v4`) — check `ros2 topic list \| grep fmu` for the actual name |
| `The message type '...' is invalid` | `px4_msgs` not built/sourced, or version mismatch with your PX4-Autopilot checkout |
| Gazebo world loads empty | `GZ_SIM_RESOURCE_PATH` not set correctly |
| `make px4_sitl` hangs on "Waiting for Gazebo world..." | Same resource path issue, or stale `px4`/`gz` processes — try `pkill -9 -f px4 && pkill -9 -f gz` |
| Can't pan/zoom/rotate camera in Gazebo | Camera starts in follow-mode — click into the window and press **Escape** |
| `commander arm` denied: "Resolve system health failures first" | Run `commander check` in the `pxh>` console to see the specific failing check |
| No detections with `perception_without_nn` | It only sees orange (`hsv_lower`/`hsv_upper`) round blobs of at least `min_area_px` (30 px at half resolution, i.e. a 0.22 m ball out to ~8 m). The sim balls are orange; set `publish_debug:=true` and view `/perception/debug_mask` to see what passes the colour filter |
| (YOLO `perception_node`) fails to load the model | It loads `~/ros2_ws/yolo11n.pt` by default (`model_path` parameter) — check the file is there |
| `perception_node` exits with `target_class ... not in model classes` | `target_class` must be one of the model's classes (`sports ball` for `yolo11n.pt`, or `ball` for the custom model) |
| Drone flies (PX4 odometry changes) but isn't visible in the Gazebo window, and `x500_depth_0` is missing from the Entity Tree | The GUI missed the drone's spawn at startup. Close the Gazebo window and start a new one: `GZ_SIM_RESOURCE_PATH=/opt/ros/jazzy/share:$HOME/PX4-Autopilot/Tools/simulation/gz/models:$HOME/PX4-Autopilot/Tools/simulation/gz/worlds gz sim -g` |
| Plot shows only a few detections / drone arrives late | Detection rate is the bottleneck — check `ros2 topic hz /detected_object` and Gazebo's real-time factor (`gz topic -e -t /stats -n 1`) |
