#!/usr/bin/env python3
"""Spawn the ball at (X, Y, Z) gliding at constant velocity (VX, VY, VZ), no gravity.

Usage: glide_ball.py [X] [Y] [Z] [VX] [VY] [VZ]
       defaults: 1.6 2.5 4.4  -0.8 0 0      (WORLD env var selects the world, default 'iris_runway')

Gazebo frame (x east, y north, z up). The drone spawns facing +y (yaw 90 deg
in drone_world.sdf), so the defaults put the ball 2.5 m ahead of it (+y),
1.6 m to the right of its heading (+x), at camera height, moving left across
the view (-x) at 0.8 m/s.

Uses Gazebo's VelocityControl system, which holds a model at a constant
velocity. It is a model-level plugin, so no change to the world file is needed.
Rerunning removes the previous ball first.
"""
import os
import sys

from gz.msgs10.boolean_pb2 import Boolean
from gz.msgs10.entity_factory_pb2 import EntityFactory
from gz.msgs10.entity_pb2 import Entity
from gz.transport13 import Node

a = [float(v) for v in sys.argv[1:7]]
defaults = [1.6, 2.5, 4.4, -0.8, 0.0, 0.0]
x, y, z, vx, vy, vz = a + defaults[len(a):]
world = os.environ.get('WORLD', 'iris_runway')

SDF = f"""<?xml version="1.0"?>
<sdf version="1.9">
  <model name="drop_ball">
    <plugin filename="gz-sim-velocity-control-system" name="gz::sim::systems::VelocityControl">
      <initial_linear>{vx} {vy} {vz}</initial_linear>
    </plugin>
    <link name="link">
      <gravity>false</gravity>
      <inertial>
        <mass>0.43</mass>
        <inertia><ixx>0.00208</ixx><iyy>0.00208</iyy><izz>0.00208</izz></inertia>
      </inertial>
      <visual name="visual"><geometry><sphere><radius>0.11</radius></sphere></geometry></visual>
    </link>
  </model>
</sdf>"""

node = Node()

rm = Entity()
rm.name = 'drop_ball'
rm.type = Entity.MODEL
node.request(f'/world/{world}/remove', rm, Entity, Boolean, 1000)

req = EntityFactory()
req.sdf = SDF
req.name = 'drop_ball'
req.pose.position.x = x
req.pose.position.y = y
req.pose.position.z = z
ok, _ = node.request(f'/world/{world}/create', req, EntityFactory, Boolean, 3000)
if not ok:
    sys.exit('spawn request failed (is the sim running / world name right?)')
print(f'ball gliding from ({x}, {y}, {z}) at ({vx}, {vy}, {vz}) m/s')
