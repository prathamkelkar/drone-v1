#!/usr/bin/env python3
"""Spawn the ball at (X, Y, Z) and throw it with velocity (VX, VY, VZ) m/s.

Usage: launch_ball.py X Y Z V0             kick straight up at V0
       launch_ball.py X Y Z VX VY VZ       throw in any direction (e.g. a lob)
       defaults: 3 -0.6 4 6                WORLD=default (env) selects the world

Gazebo frame: x east (the drone's camera looks along +x), y north, z up.

Needs Gazebo's ApplyLinkWrench system. PX4's gz_bridge/server.config already
loads it for every world, so nothing needs adding. Do not add it as a
<plugin> in the world .sdf: a world that declares any plugins stops the
server.config systems (physics, sensors, ...) from loading.

The wrench lasts one physics step (0.004 s in PX4's world), so
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
DT = 0.004

x = float(sys.argv[1]) if len(sys.argv) > 1 else 3.0
y = float(sys.argv[2]) if len(sys.argv) > 2 else -0.6
z = float(sys.argv[3]) if len(sys.argv) > 3 else 4.0
if len(sys.argv) > 6:
    vel = [float(v) for v in sys.argv[4:7]]
else:
    vel = [0.0, 0.0, float(sys.argv[4]) if len(sys.argv) > 4 else 6.0]
world = os.environ.get('WORLD', 'default')
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
msg.wrench.force.x = MASS * vel[0] / DT
msg.wrench.force.y = MASS * vel[1] / DT
msg.wrench.force.z = MASS * vel[2] / DT
wrench_pub.publish(msg)
print(f'ball spawned at ({x}, {y}, {z}) and thrown at ({vel[0]}, {vel[1]}, {vel[2]}) m/s')
