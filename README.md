# ArduPilot ball-intercept simulation (MAVROS + Gazebo + ROS 2)

A forward-camera Iris quadcopter detects a thrown orange ball, predicts its
trajectory, and flies to intercept it. This simulation uses **MAVROS over
MAVLink**, not ArduPilot DDS or PX4. QGroundControl is for the later hardware
phase; MAVProxy is used here for SITL diagnostics.

```
/camera/image_raw -> perception_without_nn (HSV; default)
  -> object_localizer (2D -> 3D via TF)
  -> object_kalman_filter -> trajectory_predictor_ellipsoid -> offboard_inercept_node
  -> MAVROS (/mavros/setpoint_raw/local) -> ArduPilot (GUIDED)
```

Stack: ROS 2 Jazzy, Gazebo Harmonic, ArduPilot SITL (ArduCopter, `iris_cam`
model with a forward 640×640 camera), MAVROS. All frames are ROS-standard ENU (world)
/ FLU (body). TF chain: `world -> map` (identity, static) `-> base_link`
(`odom_to_tf`, from `/mavros/local_position/odom`) `-> camera_link` (static,
optical frame).

| Package | Contents |
|---|---|
| `perception` | detectors: HSV colour blob (`perception_without_nn`, default) and YOLO (`perception_node`) |
| `state_estimation` | `odom_to_tf`, `object_localizer`, `object_kalman_filter`, `rotate_command`, `mavros_setup`, the Gazebo models/world and `full_pipeline.launch.py` |
| `plan_and_control` | intercept-point solvers |
| `intercept` | flies the drone in GUIDED mode via MAVROS |

## Clean setup: native Ubuntu 24.04 Desktop, x86_64

Use a machine with working OpenGL acceleration. WSL/VM and other ROS/Gazebo
versions are not validated by this runbook. The ArduPilot/Gazebo source hashes
below match the local checkouts used to develop the project, but the *entire*
clean-install sequence has not yet been tested on a second machine.

### 1. ROS 2 Jazzy

These commands follow the [official ROS 2 Jazzy Ubuntu guide](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html).
If ROS is already installed, check that guide before adding a duplicate apt
source. On a clean Ubuntu 24.04 install:

```bash
sudo apt update
sudo apt install -y curl git lsb-release gnupg software-properties-common
sudo add-apt-repository universe
sudo apt update
ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F 'tag_name' | awk -F '"' '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.noble_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb
sudo apt update
sudo apt install -y ros-jazzy-desktop ros-dev-tools python3-rosdep python3-colcon-common-extensions
source /opt/ros/jazzy/setup.bash
ros2 --help
```

Source `/opt/ros/jazzy/setup.bash` in each new ROS terminal. Do **not** use
`sudo ros2 ...`; the root shell does not inherit your ROS setup.

### 2. Gazebo Harmonic and Python bindings

The [Gazebo Harmonic Ubuntu guide](https://gazebosim.org/docs/harmonic/install_ubuntu/)
provides this apt source. `gz-harmonic` includes the `gz.transport13` and
`gz.msgs10` Python bindings used by the ball launcher and recording tools.

```bash
sudo curl https://packages.osrfoundation.org/gazebo.gpg --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null
sudo apt update
sudo apt install -y gz-harmonic libgz-sim8-dev rapidjson-dev libopencv-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl
gz sim --version
/usr/bin/python3 -c 'import gz.transport13, gz.msgs10; print("Gazebo Python bindings OK")'
```

### 3. ArduPilot SITL and its Python venv

The [ArduPilot Linux build guide](https://ardupilot.org/dev/docs/building-setup-linux.html)
provides the prerequisites script. On Ubuntu 24.04 it creates
`~/venv-ardupilot`; do not activate that venv in ROS/colcon terminals. This
project's `WP_*` controller parameters match ArduPilot checkout
`113108bd69954dfe9faed49f025601ffcaff2886` (ArduCopter 4.8.0-dev), not
necessarily an older stable release.

```bash
cd "$HOME"
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
cd ardupilot
git checkout 113108bd69954dfe9faed49f025601ffcaff2886
git submodule update --init --recursive
DO_PYTHON_VENV_ENV=0 Tools/environment_install/install-prereqs-ubuntu.sh -y
source "$HOME/venv-ardupilot/bin/activate"
./waf configure --board sitl
./waf copter
deactivate
```

The prerequisites script installs MAVProxy into the venv. The project's SITL
script uses the absolute `sim_vehicle.py` path, so `which sim_vehicle.py`
need not find it.

### 4. ArduPilot Gazebo plugin

Build the [official plugin](https://github.com/ArduPilot/ardupilot_gazebo)
at the revision whose Iris model this workspace uses:

```bash
cd "$HOME"
git clone https://github.com/ArduPilot/ardupilot_gazebo.git
cd ardupilot_gazebo
git checkout 082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5
export GZ_VERSION=harmonic
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j4
test -f build/libArduPilotPlugin.so
```

### 5. MAVROS, the project, and its dependencies

The [MAVROS installation guide](https://github.com/mavlink/mavros/blob/ros2/docs/installation.md)
requires GeographicLib datasets. Run the installed script directly under
`sudo`; **not** `sudo ros2 run ...`.

```bash
sudo apt install -y ros-jazzy-mavros ros-jazzy-mavros-extras \
  ros-jazzy-ros-gz-bridge ros-jazzy-vision-msgs ros-jazzy-cv-bridge \
  ros-jazzy-tf2-ros ros-jazzy-tf2-geometry-msgs \
  python3-numpy python3-scipy python3-opencv python3-matplotlib ffmpeg
sudo /opt/ros/jazzy/lib/mavros/install_geographiclib_datasets.sh
test -f /usr/share/GeographicLib/geoids/egm96-5.pgm
```

Clone a revision containing **this README**, the four `src/` packages,
`src/scripts/`, and the camera/ball models. If a fresh clone lacks these,
the current workspace changes have not yet been published.

```bash
cd "$HOME"
git clone https://github.com/prathamkelkar/drone-v1.git ros_ardupilot_ws
cd ros_ardupilot_ws
test -f src/scripts/start_sitl.sh
test -f src/state_estimation/models/launch_ball.py
source /opt/ros/jazzy/setup.bash
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then sudo rosdep init; fi
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
ros2 pkg prefix --share state_estimation
test -f "$(ros2 pkg prefix --share state_estimation)/models/ardupilot/worlds/drone_world.sdf"
```

Use system `/usr/bin/python3` for ROS/Gazebo tools. The default HSV detector
does **not** need Ultralytics, PyTorch, CUDA, or a YOLO weights download. Do
not install Ultralytics into the system/user Python environment for this
workflow; it can replace NumPy and break apt-installed `cv_bridge`.

## Run the HSV/ballistic simulation

Use separate terminals. **Do not start a second `gz sim`**: the pipeline
launches the custom world. Do not manually `arm` or `takeoff` while the
autonomous interceptor is running; it sets `GUIDED`, arms, takes off to 4 m,
and hovers. `FRAME_CLASS 1` and `FRAME_TYPE 1` are already applied by
`src/scripts/intercept.parm`, so no manual parameter edit/reboot is needed.

**Terminal 1 — ArduPilot SITL and MAVProxy.** Start Terminal 2 immediately
afterward; SITL can wait briefly for Gazebo's JSON connection. The script
activates the ArduPilot venv itself, uses the absolute `sim_vehicle.py` path,
loads `intercept.parm`, and disables MAVProxy stream-rate requests. This
ArduPilot revision automatically forwards MAVLink to `127.0.0.1:14550`.

```bash
cd "$HOME/ros_ardupilot_ws"
src/scripts/start_sitl.sh
```

**Terminal 2 — Gazebo, bridge, MAVROS, HSV, KF, predictor, controller.**
The plugin/model paths belong in this terminal, which starts Gazebo. Do not
run `source ~/.bashrc` after the exports.

```bash
cd "$HOME/ros_ardupilot_ws"
source /opt/ros/jazzy/setup.bash
source install/setup.bash
export GZ_VERSION=harmonic
export GZ_SIM_SYSTEM_PLUGIN_PATH="$HOME/ardupilot_gazebo/build${GZ_SIM_SYSTEM_PLUGIN_PATH:+:$GZ_SIM_SYSTEM_PLUGIN_PATH}"
export GZ_SIM_RESOURCE_PATH="$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:$(ros2 pkg prefix --share state_estimation)/models/ardupilot${GZ_SIM_RESOURCE_PATH:+:$GZ_SIM_RESOURCE_PATH}"
ros2 launch state_estimation full_pipeline.launch.py \
  perception:=hsv motion:=ballistic perception_device:=cpu
```

The launch stages are spaced by about 35 **wall-clock** seconds; wait until
`/mavros/state` reports `connected: true`, `mode: GUIDED`, `armed: true`, and
the drone has settled near 4 m. The `mavros_setup` node turns MAVROS TF off
and requests MAVLink message IDs 30/31/32 at 100 Hz. This is a request, not a
guaranteed received rate. The camera SDF requests 30 Hz at 640×640; rates
measured in wall time can be lower when Gazebo runs below real time.

**Terminal 3 — readiness checks.** Use a ROS-sourced shell. Run the two `hz`
commands one at a time and press Ctrl-C after each measurement.

```bash
cd "$HOME/ros_ardupilot_ws"
source /opt/ros/jazzy/setup.bash
source install/setup.bash
ros2 topic echo /mavros/state --once
ros2 topic echo /mavros/local_position/odom --once
ros2 topic echo /camera/camera_info --once
ros2 param get /mavros/local_position tf.send
ros2 topic hz /mavros/local_position/odom --wall-time
ros2 topic hz /camera/image_raw --wall-time
```

`ros2 topic hz` reports the rate its *subscriber* receives; large image
deserialization can slow the measurement itself. Compare with Gazebo's
real-time factor and native camera topic before concluding the sensor is
slow. Do not expect 100 Hz *wall-clock* odometry unless the simulator is
near real time and the MAVLink/MAVROS path can sustain it.

**Terminal 4 — throw one ball after hover.** The no-argument launcher reads
the live `iris_cam` pose, spawns an orange ball 5.2 m ahead and 0.3 m to
camera-right, then accelerates it for 0.2 *simulated* seconds toward about
3.5 m/s toward the drone and 5.5 m/s upward. It then coasts under gravity
in a visible **parabolic arc**, not free-fall from rest. The ascending arc is
checked against the camera FOV; that does not guarantee a physical catch.

```bash
cd "$HOME/ros_ardupilot_ws"
/usr/bin/python3 src/state_estimation/models/launch_ball.py
```

Look for `Gazebo verified release at ... coast az=...` with vertical
acceleration near `-9.81 m/s²`. If that line does not appear, the throw did
not pass Gazebo verification; do not judge the planner from that run. The
launcher removes any previous `drop_ball` before spawning a new one.

## Record and judge an attempt

After the drone is hovering, create a fresh output directory. In every
recorder terminal, run the common setup below and start one recorder
**before** the Terminal 4 ball throw. Use a new `run_XX` directory for each
attempt. The scripts' `--duration` is wall time; allow for a slow Gazebo
real-time factor.

```bash
cd ~/ros_ardupilot_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
mkdir -p test_runs/run_01
```

Then run **one** of the following in each separate terminal:

```bash
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

Stop the bag with Ctrl-C. `HIT` in `intercept_check.py` uses a generous 0.49 m
center-distance threshold, not proof of a real catch. Inspect the closest
3-D distance and the flight video. `No feasible intercept found` can mean
the estimate was late/noisy, the target is outside configured limits, or the
timing model is optimistic; check detection and KF data before altering the
throw.

## Quick checks

```bash
ros2 topic echo /mavros/state --once                 # connected, GUIDED, armed
ros2 param get /mavros/local_position tf.send        # false
ros2 run tf2_ros tf2_echo world camera_link          # Ctrl-C after reading
ros2 topic echo /detected_object --once              # after the ball is visible
ros2 topic echo /estimation/object_state --once      # after detection
ros2 topic echo /planning/intercept_ellipsoid --once # only if feasible
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Gazebo world loads without the drone | `GZ_SIM_RESOURCE_PATH` in Terminal 2 must include the installed `state_estimation` model directory and `~/ardupilot_gazebo/models`. |
| SITL waits for JSON | Start Terminal 2; confirm `GZ_SIM_SYSTEM_PLUGIN_PATH` includes `~/ardupilot_gazebo/build`. |
| `/mavros/state` stays disconnected | Check the SITL/MAVProxy link and UDP 14550; do not run a second SITL or MAVProxy. The pinned `sim_vehicle.py` adds the UDP output automatically. |
| Arming rejected repeatedly | Read the Copter/MAVProxy pre-arm message; check that `FRAME_CLASS 1` and `FRAME_TYPE 1` loaded from `intercept.parm`. Do not reboot the running SITL as a first fix. |
| Camera image missing | Check the bridge log. Gazebo publishes `/camera/image`, bridged to ROS `/camera/image_raw`. |
| Odom or camera wall Hz is low | Check Gazebo real-time factor and machine load; confirm `mavros_setup` completed. `--wall-time` is not simulated Hz. |
| Empty KF plot | Check `/detected_object`, TF and the orange ball; start the plotter before throwing. |
| `cv_bridge` / NumPy error | Use system Python; remove a conflicting user-level NumPy installation from the ROS shell. |

The HSV path does not use YOLO. `motion:=ballistic` switches both KF gravity
and the predictor's object model; `motion:=linear` is only for the
`glide_*.py` test objects. MAVROS waypoint, geofence, and rally-point
plugins are disabled for this direct-GUIDED simulation; review safety
requirements before using this config on hardware. `intercept.parm` and the
limits in `full_pipeline.launch.py` are *controller command limits*, not
validated airframe maxima. A full end-to-end autonomous HIT on a clean
second machine is **not yet demonstrated**; this is the procedure to test
it, not a claim that every throw will be caught.

## Local verification status

On the current development machine, `colcon build --symlink-install` builds
all four packages. The focused math/control tests pass:

```bash
cd "$HOME/ros_ardupilot_ws"
source /opt/ros/jazzy/setup.bash
source install/setup.bash
/usr/bin/python3 -m pytest -q \
  src/intercept/test/test_setpoint_utils.py \
  src/plan_and_control/test/test_ellipsoid_limits.py \
  src/state_estimation/test/test_kalman_gravity.py
```

Result on 2026-10-15: **22 passed**. The broader `colcon test` suite is
**not green** because of existing flake8/pep257 style failures; that does
not establish an end-to-end flight result. The clean-machine install and
autonomous catch still need to be repeated and recorded.
