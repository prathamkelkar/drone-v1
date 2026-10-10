"""
Full intercept pipeline on ArduPilot SITL + Gazebo Harmonic + MAVROS.

ArduPilot SITL (sim_vehicle.py) is NOT started here: it needs the
~/venv-ardupilot venv and an interactive MAVProxy prompt, so run it in its
own terminal (see README.md / scripts/start_sitl.sh) before or right after
starting this launch file.

Startup is staged with TimerActions. The sim runs at ~36% real time, so the
delays below are generous; tune them in one place (the T_* constants).
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, ExecuteProcess, TimerAction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

DEFAULT_WORLD = os.path.expanduser(
    '/mnt/c/Users/User/OneDrive/Documents/GitHub/drone-v1/'
    'state_estimation/models/ardupilot/worlds/drone_world.sdf')

# SITL over UDP. On the real drone: /dev/ttyAMA0:921600
DEFAULT_FCU_URL = 'udp://:14550@'

# Launch-time delays (wall seconds after `ros2 launch`), in dependency order.
T_BRIDGES_MAVROS = 10.0   # ros_gz bridges + MAVROS
T_SETUP_TF = 20.0         # mavros_setup helper, static TFs, odom_to_tf
T_PERCEPTION = 25.0       # perception, localizer, Kalman filter
T_PREDICTION = 30.0       # trajectory predictor, rotate_command
T_INTERCEPT = 35.0        # interceptor (arms and takes off on its own)

# Hover/takeoff height and intercept height (m above home, ENU z). Kept equal
# so the drone catches the ball at hover height instead of having to descend
# to the ground in the ball's flight time.
INTERCEPT_HEIGHT = 4.0


def generate_launch_description():

    world_arg = DeclareLaunchArgument(
        'world', default_value=DEFAULT_WORLD,
        description='Path to the Gazebo world SDF')

    fcu_url_arg = DeclareLaunchArgument(
        'fcu_url', default_value=DEFAULT_FCU_URL,
        description='MAVROS FCU URL (SITL: udp://:14550@, real drone: /dev/ttyAMA0:921600)')

    perception_device_arg = DeclareLaunchArgument(
        'perception_device', default_value='cuda:0',
        description="Device for YOLO inference: 'cuda:0' (GPU) or 'cpu'")

    gazebo = ExecuteProcess(
        cmd=['gz', 'sim', '-v4', '-r', LaunchConfiguration('world')],
        output='screen'
    )

    # Same as `ros2 launch mavros apm.launch`, but with our overrides layered
    # on top of the stock ArduPilot config (later files win).
    mavros_share = get_package_share_directory('mavros')
    mavros = Node(
        package='mavros',
        executable='mavros_node',
        parameters=[
            os.path.join(mavros_share, 'launch', 'apm_pluginlists.yaml'),
            os.path.join(mavros_share, 'launch', 'apm_config.yaml'),
            os.path.join(get_package_share_directory('state_estimation'),
                         'config', 'mavros_overrides.yaml'),
            {
                'fcu_url': LaunchConfiguration('fcu_url'),
                'gcs_url': '',
                'tgt_system': 1,
                'tgt_component': 1,
                'fcu_protocol': 'v2.0',
            },
        ],
        output='screen'
    )

    # Waits for MAVROS/FCU, then forces tf.send=false and requests 30 Hz
    # ATTITUDE / ATTITUDE_QUATERNION / LOCAL_POSITION_NED; retries, then exits.
    mavros_setup = Node(
        package='state_estimation',
        executable='mavros_setup',
        parameters=[{'message_ids': [30, 31, 32], 'message_rate': 30.0}],
        output='screen'
    )

    bridges = ExecuteProcess(
        cmd=[
            'ros2', 'run', 'ros_gz_bridge', 'parameter_bridge',
            '/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock',
            '/camera/image@sensor_msgs/msg/Image[gz.msgs.Image',
            '/camera/camera_info@sensor_msgs/msg/CameraInfo[gz.msgs.CameraInfo',
            '--ros-args', '-r', '/camera/image:=/camera/image_raw',
        ],
        output='screen'
    )

    # world -> map: identity (MAVROS odom is in 'map', the rest of the code uses 'world')
    world_to_map = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=['--frame-id', 'world', '--child-frame-id', 'map'],
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    # base_link (FLU: x fwd, y left, z up) -> camera_link (optical: x right,
    # y down, z forward). Mount from iris_cam/model.sdf: 0.10 m forward, 0.02 m up.
    static_tf = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=[
            '--x', '0.10', '--y', '0', '--z', '0.02',
            '--qx', '-0.5', '--qy', '0.5', '--qz', '-0.5', '--qw', '0.5',
            '--frame-id', 'base_link', '--child-frame-id', 'camera_link',
        ],
        parameters=[{'use_sim_time': True}],
        output='screen'
    )

    odom_to_tf = Node(
        package='state_estimation',
        executable='odom_to_tf',
        parameters=[{'use_sim_time': True}],
        output='screen'
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
        # gravity: positive magnitude, applied along -z (ENU). 0.0 for the
        # constant-velocity test; 9.81 for thrown/dropped objects.
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
        # takeoff_height so the drone catches the ball at hover height
        # instead of having to descend to the ground in the ball's flight time.
        parameters=[{'use_sim_time': True, 'object_model': 'constant_velocity',
                     'h_target': INTERCEPT_HEIGHT, 'intercept_mode': 'independent_axes'}],
        output='screen'
    )

    # Sets GUIDED, arms, takes off to takeoff_height, hovers, then chases
    # /planning/intercept_ellipsoid. (Executable name typo is intentional.)
    interceptor = Node(
        package='intercept',
        executable='offboard_inercept_node',
        parameters=[{'use_sim_time': True, 'takeoff_height': INTERCEPT_HEIGHT}],
        output='screen'
    )

    return LaunchDescription([
        world_arg,
        fcu_url_arg,
        perception_device_arg,
        gazebo,

        TimerAction(period=T_BRIDGES_MAVROS, actions=[bridges, mavros]),

        TimerAction(period=T_SETUP_TF, actions=[
            mavros_setup,
            world_to_map,
            static_tf,
            odom_to_tf,
        ]),

        TimerAction(period=T_PERCEPTION, actions=[
            perception_node,
            object_localizer,
            kalman_filter,
        ]),

        TimerAction(period=T_PREDICTION, actions=[
            trajectory_predictor,
            rotate_command,
        ]),

        TimerAction(period=T_INTERCEPT, actions=[
            interceptor,
        ]),
    ])
