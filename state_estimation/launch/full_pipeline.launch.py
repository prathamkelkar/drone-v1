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
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PythonExpression
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

# Hover/takeoff height (m above home, ENU z).
TAKEOFF_HEIGHT = 4.0

# Drone limits shared by the predictor and the interceptor. They must not
# exceed what ArduPilot is allowed to fly (scripts/intercept.parm):
#   a_max_h 9.8 m/s^2   = g*tan(45 deg) at ATC_ANGLE_MAX 45: the cap on
#                         acceleration-only targets (chase_mode 'thrust').
#                         Velocity targets are shaped at WP_ACC (5 m/s^2, its
#                         maximum), so use a_max_h <= 5 with chase_mode 'velocity'.
#   a_max_up 4.5 m/s^2  < WP_ACC_Z 5, under the iris's full-thrust climb
#   a_max_dn 5.0 m/s^2  = WP_ACC_Z 5
#   v_max_h 20 m/s      = WP_SPD 20 (its maximum)
#   v_max_up 8, v_max_dn 4 m/s = WP_SPD_UP / WP_SPD_DN
# UNVERIFIED in sim: these were PX4 x500 numbers (a_max_h 12.6, tilt 52 deg)
# on the teleop branch, re-derived here for ArduPilot's iris.
A_MAX_H, A_MAX_UP, A_MAX_DN = 9.8, 4.5, 5.0
V_MAX_H, V_MAX_UP, V_MAX_DN = 20.0, 8.0, 4.0
# s before a commanded acceleration takes effect. ArduPilot ramps
# acceleration at PSC_NE_JERK (20 m/s^3 -> ~0.5 s to full a_max_h, ~0.25 s
# average lag). Predictor and interceptor must use the same value.
TILT_DELAY = 0.25


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

    target_class_arg = DeclareLaunchArgument(
        'target_class', default_value='plastic_bottle',
        description="YOLO class to track: 'ball', 'carton' or 'plastic_bottle' (best.pt); "
                    'only used with perception:=yolo')

    # perception_node's own default is stock yolo11n.pt ('sports ball');
    # target_class above must be a class of this model.
    yolo_model_arg = DeclareLaunchArgument(
        'yolo_model', default_value=os.path.expanduser('~/ros2_ws/best.pt'),
        description='YOLO weights for perception:=yolo (best.pt, or yolo11n.pt with '
                    "target_class:='sports ball')")

    # hsv: perception_without_nn, colour threshold for the orange test ball
    # (drop_ball / glide_ball); yolo: perception_node with best.pt.
    perception_arg = DeclareLaunchArgument(
        'perception', default_value='hsv', choices=['hsv', 'yolo'],
        description='Object detector: hsv (orange ball, no NN) or yolo')
    use_yolo = PythonExpression(["'", LaunchConfiguration('perception'), "' == 'yolo'"])
    use_hsv = PythonExpression(["'", LaunchConfiguration('perception'), "' == 'hsv'"])

    # How the test object moves. One switch keeps the Kalman filter gravity
    # and predictor object model consistent.
    #   motion:=linear     glide_ball.py / glide_bottle.py (straight line, no gravity)
    #   motion:=ballistic  launch_ball.py (thrown / dropped, gravity 9.81)
    motion_arg = DeclareLaunchArgument(
        'motion', default_value='linear', choices=['linear', 'ballistic'],
        description='Object motion model: linear (glide_*.py) or ballistic (launch_ball.py)')
    motion = LaunchConfiguration('motion')
    object_gravity = PythonExpression(["9.81 if '", motion, "' == 'ballistic' else 0.0"])
    object_model = PythonExpression(
        ["'ballistic' if '", motion, "' == 'ballistic' else 'constant_velocity'"])

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
                     'device': LaunchConfiguration('perception_device'),
                     'model_path': LaunchConfiguration('yolo_model'),
                     'target_class': LaunchConfiguration('target_class')}],
        condition=IfCondition(use_yolo),
        output='screen'
    )

    hsv_perception_node = Node(
        package='perception',
        executable='perception_without_nn',
        parameters=[{'use_sim_time': True}],
        condition=IfCondition(use_hsv),
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
        # gravity: positive magnitude, applied along -z (ENU), from the
        # 'motion' launch argument (0.0 or 9.81), from the first detection
        # (no gate).
        parameters=[{'use_sim_time': True, 'gravity': object_gravity, 'gravity_gate': False}],
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
        # h_target: lowest height above the ground (z-up) at which the ball
        # may be intercepted. A high limit (e.g. 3 m) leaves too little
        # flight time for the drone to reach a parabolic target, so the
        # predictor never publishes a point. The solver uses one vertical
        # limit: the smaller of climb and descent.
        parameters=[{'use_sim_time': True, 'object_model': object_model, 'h_target': 0.3,
                     'tilt_delay': TILT_DELAY, 'intercept_mode': 'ellipsoid',
                     'a_max_h': A_MAX_H, 'v_max_h': V_MAX_H,
                     'a_max_v': min(A_MAX_UP, A_MAX_DN), 'v_max_v': min(V_MAX_UP, V_MAX_DN)}],
        output='screen'
    )

    # Sets GUIDED, arms, takes off to takeoff_height, hovers, then chases
    # /planning/intercept_ellipsoid. (Executable name typo is intentional.)
    # The drone reaches the intercept point at full speed or still
    # accelerating, and only brakes once it is past it.
    # chase_mode 'thrust': acceleration setpoints at 100 Hz timed to the
    #   predictor's arrival time; ArduPilot turns them into tilt + thrust.
    # chase_mode 'velocity': full-speed velocity setpoint + full acceleration
    #   feedforward; the chase ends once the point is behind the drone.
    # a_brake / response_lag are only used to stop after the chase and on
    # the flight home.
    interceptor = Node(
        package='intercept',
        executable='offboard_inercept_node',
        parameters=[{'use_sim_time': True, 'takeoff_height': TAKEOFF_HEIGHT,
                     'chase_mode': 'thrust', 'setpoint_rate': 100.0,
                     'tilt_delay': TILT_DELAY,
                     'v_max_h': V_MAX_H, 'v_max_up': V_MAX_UP, 'v_max_dn': V_MAX_DN,
                     'a_max_h': A_MAX_H, 'a_max_up': A_MAX_UP, 'a_max_dn': A_MAX_DN,
                     'a_brake': A_MAX_H, 'response_lag': 0.15, 'pass_radius': 1.0,
                     # end of an attempt: stop chasing when the intercept
                     # point is reached, the target disappears for 0.5 s,
                     # after 4 s or 6 m from home; hold 2 s; fly home at
                     # 2 m/s; a new attempt needs 1 s without targets first
                     'target_timeout': 0.5, 'max_chase_time': 4.0,
                     'max_chase_distance': 6.0, 'hold_time': 2.0,
                     'return_speed': 2.0, 'return_accel': 2.0,
                     'rearm_quiet': 1.0}],
        output='screen'
    )

    return LaunchDescription([
        world_arg,
        fcu_url_arg,
        perception_device_arg,
        target_class_arg,
        yolo_model_arg,
        perception_arg,
        motion_arg,
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
            hsv_perception_node,
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
