import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, DurabilityPolicy, ReliabilityPolicy

from nav_msgs.msg import Odometry
from tf2_ros import TransformBroadcaster
from geometry_msgs.msg import TransformStamped


class OdomToTF(Node):
    def __init__(self):
        super().__init__('odom_to_tf')

        # BEST_EFFORT matches MAVROS's sensor-data QoS and also connects to reliable publishers
        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        self.declare_parameter('odom_topic', '/mavros/local_position/odom')
        topic = self.get_parameter('odom_topic').value

        self.br = TransformBroadcaster(self)
        self.sub = self.create_subscription(Odometry, topic, self.odom_callback, qos)

    def odom_callback(self, msg: Odometry):
        t = TransformStamped()
        # Stamp with the node clock (sim time), not msg.header.stamp: MAVROS
        # stamps with its own clock, which is not the /clock the pipeline uses.
        t.header.stamp = self.get_clock().now().to_msg()
        t.header.frame_id = msg.header.frame_id or 'map'
        t.child_frame_id = msg.child_frame_id or 'base_link'

        p = msg.pose.pose.position
        q = msg.pose.pose.orientation
        t.transform.translation.x = p.x
        t.transform.translation.y = p.y
        t.transform.translation.z = p.z
        t.transform.rotation.x = q.x
        t.transform.rotation.y = q.y
        t.transform.rotation.z = q.z
        t.transform.rotation.w = q.w

        self.br.sendTransform(t)


def main(args=None):
    rclpy.init(args=args)
    node = OdomToTF()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
