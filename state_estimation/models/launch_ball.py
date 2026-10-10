#!/usr/bin/env python3
"""Spawn the drop ball at (X, Y, Z) and kick it straight up at V0 m/s.

Usage: launch_ball.py [X] [Y] [Z] [V0]      (defaults: 3 -0.6 4 6)
       WORLD (env, default iris_runway = ardupilot/worlds/drone_world.sdf)
       selects the Gazebo world name; PHYSICS_DT (env, default 0.001) must
       match the world's <max_step_size>.

Needs the ApplyLinkWrench system loaded in the Gazebo world, i.e. this line
inside <world> (drone_world.sdf loads it):
  <plugin filename="gz-sim-apply-link-wrench-system"
          name="gz::sim::systems::ApplyLinkWrench"/>

The wrench lasts one physics step (PHYSICS_DT), so
impulse = F*dt = m*v0  ->  F = m*v0/dt. The push is sent right after the
spawn call returns (a few ms), so the ball has barely started to fall.
"""
import os
import sys
import time

from gz.msgs10.boolean_pb2 import Boolean
from gz.msgs10.entity_factory_pb2 import EntityFactory
from gz.msgs10.entity_pb2 import Entity
from gz.msgs10.entity_wrench_pb2 import EntityWrench
from gz.transport13 import Node

MASS = 0.43
DT = float(os.environ.get('PHYSICS_DT', '0.001'))

x = float(sys.argv[1]) if len(sys.argv) > 1 else 3.0
y = float(sys.argv[2]) if len(sys.argv) > 2 else -0.6
z = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0
v0 = float(sys.argv[4]) if len(sys.argv) > 4 else 6.0
world = os.environ.get('WORLD', 'iris_runway')
sdf = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'drop_ball.sdf')

node = Node()
wrench_pub = node.advertise(f'/world/{world}/wrench', EntityWrench)

# Remove any previous ball so the launch can be repeated.
rm = Entity()
rm.name = 'drop_ball'
rm.type = Entity.MODEL
node.request(f'/world/{world}/remove', rm, Entity, Boolean, 1000)

# Give the wrench publisher time to connect to the world's subscriber
# before the ball exists, so the push itself has no discovery delay.
time.sleep(1.0)

req = EntityFactory()
req.sdf_filename = sdf
req.name = 'drop_ball'
req.pose.position.x = x
req.pose.position.y = y
req.pose.position.z = z
ok, _ = node.request(f'/world/{world}/create', req, EntityFactory, Boolean, 3000)
if not ok:
    sys.exit('spawn request failed (is the sim running / world name right?)')

msg = EntityWrench()
msg.entity.name = 'drop_ball::link'
msg.entity.type = Entity.LINK
msg.wrench.force.z = MASS * v0 / DT
wrench_pub.publish(msg)
print(f'ball spawned at ({x}, {y}, {z}) and kicked up at ~{v0} m/s')
