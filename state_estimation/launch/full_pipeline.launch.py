from launch import LaunchDescription
from launch.actions import ExecuteProcess, TimerAction, DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch_ros.actions import Node
import os

def generate_launch_description():

    # How the test object moves. One switch keeps the Kalman filter gravity
    # and predictor object model consistent. The interceptor now consumes the
    # predictor's feasible point rather than modelling the ball separately.
    #   motion:=linear     glide_ball.py / glide_bottle.py (straight line, no gravity)
    #   motion:=ballistic  launch_ball.py (thrown / dropped, gravity 9.81)
    motion_arg = DeclareLaunchArgument(
        'motion', default_value='linear', choices=['linear', 'ballistic'],
        description='Object motion model: linear (glide_*.py) or ballistic (launch_ball.py)')
    motion = LaunchConfiguration('motion')
    object_gravity = PythonExpression(["9.81 if '", motion, "' == 'ballistic' else 0.0"])
    object_model = PythonExpression(["'ballistic' if '", motion, "' == 'ballistic' else 'constant_velocity'"])

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

    # PX4 limits that apply in offboard mode, set to the maximum the drone
    # allows (PX4's rcS applies any PX4_PARAM_<NAME> env var as
    # `param set <NAME>` at startup). Simulated x500: 2.13 kg, 34.2 N max
    # thrust (thrust/weight 1.64).
    # MPC_ACC_HOR_MAX / MPC_ACC_UP_MAX are not used by offboard control.
    px4_limits = {
        'PX4_PARAM_MPC_XY_VEL_MAX': '20.0',    # m/s, parameter maximum (default 12)
        'PX4_PARAM_MPC_Z_VEL_MAX_UP': '8.0',   # m/s, parameter maximum (default 3)
        'PX4_PARAM_MPC_Z_VEL_MAX_DN': '4.0',   # m/s, parameter maximum (default 1.5)
        # Steepest tilt at which full thrust still holds altitude:
        # acos(weight / max thrust) = 52.4 deg -> g*tan(52) = 12.6 m/s^2
        # horizontal. The parameter allows up to 89, but beyond ~52 deg the
        # drone can't hold altitude and would sink while accelerating.
        'PX4_PARAM_MPC_TILTMAX_AIR': '52.0',   # deg (default 45)
        'PX4_PARAM_MPC_THR_MAX': '1.0',        # full thrust available (default)
        # Faster tilting inside PX4's own attitude loop (the interceptor now
        # sends acceleration setpoints; PX4 turns them into tilt + thrust).
        # The attitude gain sets how fast the tilt error is commanded away
        # (rate = gain * error); at the default 4.0 a 52 deg tilt asks for
        # only 3.6 rad/s, under the 220 deg/s limit, so both are raised.
        'PX4_PARAM_MC_ROLL_P': '6.5',          # default 4.0 (range 0-12)
        'PX4_PARAM_MC_PITCH_P': '6.5',         # default 4.0
        'PX4_PARAM_MC_ROLLRATE_MAX': '480.0',  # deg/s, default 220 (range 0-1800)
        'PX4_PARAM_MC_PITCHRATE_MAX': '480.0', # deg/s, default 220
    }

    px4_gazebo = ExecuteProcess(
        cmd=['make', 'px4_sitl', 'gz_x500_depth'],
        cwd=[LaunchConfiguration('px4_dir')],
        additional_env=px4_limits,
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

    # perception_node = Node(
    #     package='perception',
    #     executable='perception_node',
    #     parameters=[{'use_sim_time': True,
    #                  'device': LaunchConfiguration('perception_device')}],
    #     output='screen'
    # )

    perception_node = Node(
        package='perception',
        executable='perception_without_nn',
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
        # gravity from the 'motion' launch argument (0.0 or 9.81), applied
        # from the first detection (no gate)
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
        # h_target: lowest height above the ground (solver uses z-up) at
        # which the ball may be intercepted. The previous 3 m limit left too
        # little flight time for the drone to reach a parabolic target, so
        # the predictor never published an intercept point.
        # Drone limits for the intercept solver, at the drone's maximum:
        #   a_max_h 12.6 m/s^2 = g*tan(52 deg tilt); v_max_h 20 = MPC_XY_VEL_MAX
        #   a_max_v 6.3 m/s^2 = full-thrust climb (34.2 N / 2.13 kg - g), the
        #     smaller of climb and descent (~7.9 m/s^2)
        #   v_max_v 4 m/s = MPC_Z_VEL_MAX_DN, the smaller of climb (8) and
        #     descent (4); the solver uses one vertical limit for both.
        parameters=[{'use_sim_time': True, 'object_model': object_model, 'h_target': 0.3,
                     'tilt_delay': 0.1,
                     'intercept_mode': 'ellipsoid',
                     'a_max_h': 12.6, 'v_max_h': 20.0, 'a_max_v': 6.3, 'v_max_v': 4.0}],
        output='screen'
    )

    interceptor = Node(
            package='intercept',
            executable='offboard_inercept_node',
            # In every chase mode the drone reaches the intercept point at full
            # speed or still accelerating, and only brakes once it is past it.
            # Limits: speed caps match the PX4 limits above; a_max_* are the
            # drone's accelerations (g*tan(52 deg) horizontal, full-thrust
            # climb, minimum-thrust descent). a_brake / response_lag are only
            # used to stop after the chase and on the flight home.
            # chase_mode 'velocity': full-speed velocity setpoint + full
            # acceleration feedforward toward the predictor's point; the chase
            # ends once the point is behind the drone (within pass_radius).
            # chase_mode 'thrust': our own guidance drives toward the latest
            # /planning/intercept_ellipsoid point with acceleration setpoints
            # at 100 Hz; PX4's own loops turn them into tilt + thrust.
            # 'velocity' = PX4 velocity loop + feedforward (previous).
            # Both modes consume /planning/intercept_ellipsoid; neither starts
            # a separate chase directly from the Kalman-filter ball state.
            parameters=[{'use_sim_time': True, 'chase_mode': 'thrust',
                         'tilt_max_deg': 52.0,
                         'tilt_delay': 0.1,
                         'v_max_h': 20.0, 'v_max_up': 8.0, 'v_max_dn': 4.0,
                         'a_max_h': 12.6, 'a_max_up': 6.3, 'a_max_dn': 7.9,
                         'a_brake': 12.6, 'response_lag': 0.15, 'pass_radius': 1.0,
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
        motion_arg,
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

