# Simple Quadcopter Teleop (PX4 + Gazebo SITL)

A keyboard teleop node for controlling a PX4-simulated quadcopter in Gazebo via offboard velocity setpoints, using ROS 2 and `px4_msgs`.

## Prerequisites

- Ubuntu 24.04
- ROS 2 Jazzy
- Gazebo Sim (Harmonic, `gz sim` v8.x)
- PX4-Autopilot (built for `gz_x500` simulation target)
- Python 3.12+

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

Clone or place this package (`simple_quadcopter_teleop`) into `~/ros2_ws/src` as well.

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

## Running the Simulation

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