from launch import LaunchDescription
from launch.actions import ExecuteProcess, TimerAction, DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
import os

def generate_launch_description():

    micro_xrce_agent = ExecuteProcess(
        cmd=['MicroXRCEAgent', 'udp4', '-p', '8888'],
        output='screen'
    )

    mavproxy = ExecuteProcess(
        cmd=['mavproxy.py', '--master=udp:127.0.0.1:14550'],
        output='screen'
    )

    px4_dir_arg = DeclareLaunchArgument(
        'px4_dir',
        default_value=os.path.expanduser('~/PX4-Autopilot'),
        description='Path to PX4-Autopilot directory'
    )

    px4_gazebo = ExecuteProcess(
        cmd=['make', 'px4_sitl', 'gz_x500_depth'],
        cwd=[LaunchConfiguration('px4_dir')],
        output='screen'
    )

    clock_bridge = ExecuteProcess(
        cmd=[
            'ros2', 'run', 'ros_gz_bridge', 'parameter_bridge',
            '/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock'
        ],
        output='screen'
    )

    image_bridge = ExecuteProcess(
        cmd=[
            'ros2', 'run', 'ros_gz_bridge', 'parameter_bridge',
            '/world/default/model/x500_depth_0/link/camera_link/sensor/IMX214/image@sensor_msgs/msg/Image[gz.msgs.Image',
            '--ros-args', '-r',
            '/world/default/model/x500_depth_0/link/camera_link/sensor/IMX214/image:=/camera/image_raw'
        ],
        output='screen'
    )

    camera_info_bridge = ExecuteProcess(
        cmd=[
            'ros2', 'run', 'ros_gz_bridge', 'parameter_bridge',
            '/world/default/model/x500_depth_0/link/camera_link/sensor/IMX214/camera_info@sensor_msgs/msg/CameraInfo[gz.msgs.CameraInfo',
            '--ros-args', '-r',
            '/world/default/model/x500_depth_0/link/camera_link/sensor/IMX214/camera_info:=/camera/camera_info'
        ],
        output='screen'
    )

    static_tf = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=['0.1', '0', '-0.05', '0', '0', '0', 'base_link', 'camera_link'],
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    px4_odom_to_tf = Node(
        package='state_estimation',
        executable='px4_odom_to_tf',
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    perception_node = ExecuteProcess(
        cmd=[
            'gnome-terminal', '--', 'bash', '-c',
            'source ~/ros2_ws/install/setup.bash && '
            'ros2 run perception perception_node --ros-args -p use_sim_time:=true; '
            'exec bash'
        ],
        output='screen'
    )

    object_localizer = Node(
        package='state_estimation',
        executable='object_localizer',
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    kalman_filter = Node(
        package='state_estimation',
        executable='object_kalman_filter',
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    rotate_command = Node(
        package='state_estimation',
        executable='rotate_command',
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    return LaunchDescription([
        px4_dir_arg,
        micro_xrce_agent,
        mavproxy,
        px4_gazebo,

        TimerAction(period=15.0, actions=[
            clock_bridge,
            image_bridge,
            camera_info_bridge
        ]),

        TimerAction(period=20.0, actions=[
            static_tf,
            px4_odom_to_tf
        ]),

        TimerAction(period=25.0, actions=[
            perception_node,
            object_localizer,
            kalman_filter,
        ]),
        TimerAction(period=30.0, actions=[
            rotate_command
        ])
    ])

