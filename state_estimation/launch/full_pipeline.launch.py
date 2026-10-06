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
        # base_link is PX4's FRD body frame (x fwd, y right, z down). The
        # localizer treats camera_link as an optical frame (x right, y down,
        # z forward/depth), so rotate optical -> FRD: x_opt=y_body,
        # y_opt=z_body, z_opt=x_body  (120 deg about (1,1,1)).
        arguments=[
            # Mount from PX4's x500_depth/OakD-Lite model.sdf: camera at
            # (0.12, 0.03, 0.242) + IMX214 sensor offset (0.012, -0.03, 0.019)
            # in FLU -> (0.132, 0, 0.261 up) -> FRD z = -0.261.
            '--x', '0.132', '--y', '0', '--z', '-0.261',
            '--qx', '0.5', '--qy', '0.5', '--qz', '0.5', '--qw', '0.5',
            '--frame-id', 'base_link', '--child-frame-id', 'camera_link',
        ],
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    px4_odom_to_tf = Node(
        package='state_estimation',
        executable='px4_odom_to_tf',
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    perception_device_arg = DeclareLaunchArgument(
        'perception_device',
        default_value='cuda:0',
        description="Device for YOLO inference: 'cuda:0' (GPU) or 'cpu'"
    )

    perception_node = Node(
        package='perception',
        executable='perception_node',
        parameters=[{'use_sim_time': True,
                     'device': LaunchConfiguration('perception_device')}],
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
        # gravity 0.0 for the constant-velocity test; 9.81 for thrown objects
        parameters=[{'use_sim_time': True, 'gravity': 0.0}],
        output='screen'
    )

    rotate_command = Node(
        package='state_estimation',
        executable='rotate_command',
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    trajectory_predictor = Node(
        package='plan_and_control',
        executable='trajectory_predictor_ellipsoid',
        # h_target: height (above the drone's start point, z-up) at which the
        # ball is intercepted. Keep it equal to the interceptor's
        # takeoff_height (4.0) so the drone catches the ball at hover height
        # instead of having to descend to the ground in the ball's flight time.
        parameters=[{'use_sim_time': True, 'object_model': 'constant_velocity', 'h_target': 4.0,
                     'intercept_mode': 'independent_axes'}],
        output='screen'
    )

    interceptor = Node(
            package='intercept',
            executable='offboard_inercept_node',
            parameters=[{'use_sim_time': True}],
            output='screen'
    )

    return LaunchDescription([
        px4_dir_arg,
        perception_device_arg,
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
            rotate_command,
            trajectory_predictor
        ]),
        TimerAction(period=35.0, actions=[
            interceptor
        ]),
    ])

