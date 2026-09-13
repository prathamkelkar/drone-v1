import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

class PerceptionNode(Node):
    def __init__(self):
        super().__init__('perception_node')

        