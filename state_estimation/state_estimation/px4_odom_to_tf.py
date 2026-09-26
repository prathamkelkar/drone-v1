import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, HistoryPolicy, DurabilityPolicy, ReliabilityPolicy

from px4_msgs.msg import VehicleOdometry
from tf2_ros import TransformBroadcaster
from geometry_msgs.msg import TransformStamped

class PX4_Odom_to_TF(Node):
    def __init__(self):
        super().__init__('px4_odom_to_tf')
        
        qos = QoSProfile(
                reliability=ReliabilityPolicy.BEST_EFFORT,
                durability=DurabilityPolicy.VOLATILE,
                history=HistoryPolicy.KEEP_LAST,
                depth=1
        )
    
        self.br = TransformBroadcaster(self)
        self.sub = self.create_subscription(VehicleOdometry, '/fmu/out/vehicle_odometry', self.odom_callback, qos)

    def odom_callback(self, msg: VehicleOdometry):

        t = TransformStamped()
        t.header.stamp = self.get_clock().now().to_msg()
        t.header.frame_id = 'world'
        t.child_frame_id = 'base_link'

        t.transform.translation.x = float(msg.position[0])
        t.transform.translation.y = float(msg.position[1])
        t.transform.translation.z = float(msg.position[2])

        t.transform.rotation.w = float(msg.q[0])
        t.transform.rotation.x = float(msg.q[1])
        t.transform.rotation.y = float(msg.q[2])
        t.transform.rotation.z = float(msg.q[3])

        self.br.sendTransform(t)

def main(args=None):
    rclpy.init(args=args)
    node = PX4_Odom_to_TF()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == "__main__":
    main()



    