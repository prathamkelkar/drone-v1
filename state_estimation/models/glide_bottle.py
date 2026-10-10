#!/usr/bin/env python3
"""Spawn an upright plastic bottle at (X, Y, Z) gliding at constant velocity, no gravity.

Usage: glide_bottle.py [X] [Y] [Z] [VX] [VY] [VZ] [--mesh]
       defaults: 2.5 -1.6 4.4  0 0.8 0      (WORLD env var selects the world, default 'iris_runway')

Same motion as glide_ball.py: Gazebo frame (x east, y north, z up), 2.5 m ahead
of the drone, 1.6 m to the right, at camera height, moving left at 0.8 m/s.

Bottle body diameter is 0.22 m = KNOWN_OBJECT_WIDTH in object_localizer.py,
so the detection box width (bottle seen from the side) gives the right range.

  default : plastic_bottle.sdf, a translucent bottle built from primitives (~0.54 m tall)
  --mesh  : the 'Water Bottle' model from Gazebo Fuel (iche033), scaled x2.02 so
            its 0.109 m diameter becomes 0.22 m (~0.53 m tall). Needs a one-time
            download:  gz fuel download -u "https://fuel.gazebosim.org/1.0/iche033/models/Water Bottle"

Rerunning removes the previous bottle (and any ball from glide_ball.py) first.
"""
import os
import sys

from gz.msgs10.boolean_pb2 import Boolean
from gz.msgs10.entity_factory_pb2 import EntityFactory
from gz.msgs10.entity_pb2 import Entity
from gz.transport13 import Node

HERE = os.path.dirname(os.path.realpath(__file__))
FUEL_MESH = os.path.expanduser(
    '~/.gz/fuel/fuel.gazebosim.org/iche033/models/water bottle/3/meshes/WaterBottle.glb')
MESH_SCALE = 0.22 / 0.1089   # mesh diameter 0.1089 m -> 0.22 m

use_mesh = '--mesh' in sys.argv
a = [float(v) for v in sys.argv[1:] if v != '--mesh'][:6]
defaults = [2.5, -1.6, 4.4, 0.0, 0.8, 0.0]
x, y, z, vx, vy, vz = a + defaults[len(a):]
world = os.environ.get('WORLD', 'iris_runway')

velocity_plugin = f"""
    <plugin filename="gz-sim-velocity-control-system" name="gz::sim::systems::VelocityControl">
      <initial_linear>{vx} {vy} {vz}</initial_linear>
    </plugin>"""

if use_mesh:
    if not os.path.exists(FUEL_MESH):
        sys.exit(f'mesh not found: {FUEL_MESH}\n(run the gz fuel download command in this file\'s docstring)')
    # The glTF mesh imports lying on its side; roll 90 deg to stand it up.
    sdf = f"""<?xml version="1.0"?>
<sdf version="1.9">
  <model name="glide_bottle">{velocity_plugin}
    <link name="link">
      <gravity>false</gravity>
      <inertial><mass>0.5</mass><inertia><ixx>0.012</ixx><iyy>0.012</iyy><izz>0.003</izz></inertia></inertial>
      <visual name="visual">
        <pose>0 0 0 1.5708 0 0</pose>
        <geometry><mesh><uri>{FUEL_MESH}</uri><scale>{MESH_SCALE} {MESH_SCALE} {MESH_SCALE}</scale></mesh></geometry>
      </visual>
    </link>
  </model>
</sdf>"""
else:
    sdf = open(os.path.join(HERE, 'plastic_bottle.sdf')).read()
    sdf = sdf.replace('<model name="plastic_bottle">',
                      '<model name="glide_bottle">' + velocity_plugin, 1)

node = Node()
for name in ('glide_bottle', 'drop_ball'):
    rm = Entity()
    rm.name = name
    rm.type = Entity.MODEL
    node.request(f'/world/{world}/remove', rm, Entity, Boolean, 1000)

req = EntityFactory()
req.sdf = sdf
req.name = 'glide_bottle'
req.pose.position.x = x
req.pose.position.y = y
req.pose.position.z = z
ok, _ = node.request(f'/world/{world}/create', req, EntityFactory, Boolean, 3000)
if not ok:
    sys.exit('spawn request failed (is the sim running / world name right?)')
print(f'{"mesh" if use_mesh else "primitive"} bottle gliding from ({x}, {y}, {z}) at ({vx}, {vy}, {vz}) m/s')
