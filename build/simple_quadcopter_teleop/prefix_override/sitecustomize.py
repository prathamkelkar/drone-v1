import sys
if sys.prefix == '/usr':
    sys.real_prefix = sys.prefix
    sys.prefix = sys.exec_prefix = '/home/prathamkelkar/ros2_ws/install/simple_quadcopter_teleop'
