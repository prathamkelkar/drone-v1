#!/usr/bin/env bash
# Start ArduPilot SITL for the Gazebo iris model (terminal T2).
# Runs in its own interactive terminal: it needs the ArduPilot venv and
# leaves you at the MAVProxy prompt (STABILIZE> / GUIDED>).
# intercept.parm raises ArduPilot's speed / acceleration / lean limits for the
# interceptor (applied on top of the defaults at every start).
set -e
PARM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/intercept.parm"
source ~/venv-ardupilot/bin/activate
cd ~/ardupilot/ArduCopter
exec "$HOME/ardupilot/Tools/autotest/sim_vehicle.py" \
    -v ArduCopter -f gazebo-iris --model JSON --console \
    --mavproxy-args="--streamrate=-1" \
    --add-param-file="$PARM" "$@"
