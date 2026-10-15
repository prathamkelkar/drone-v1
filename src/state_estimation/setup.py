from setuptools import find_packages, setup
import os
from glob import glob

package_name = 'state_estimation'


def package_model_files():
    """Install simulation assets while preserving their directory layout."""
    return [
        (os.path.join('share', package_name, os.path.dirname(path)), [path])
        for path in glob('models/**/*', recursive=True)
        if os.path.isfile(path)
    ]


setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
        (os.path.join('share', package_name, 'config'), glob('config/*.yaml')),
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ] + package_model_files(),
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='prathamkelkar',
    maintainer_email='pratham.kel@gmail.com',
    description='Odometry-to-TF, object localisation and Kalman filtering for the ArduPilot/MAVROS intercept drone, plus the full pipeline launch file.',
    license='TODO: License declaration',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'object_localizer = state_estimation.object_localizer:main',
            'odom_to_tf = state_estimation.odom_to_tf:main',
            'object_kalman_filter = state_estimation.object_kalman_filter:main',
            'rotate_command = state_estimation.rotate_command:main',
            'mavros_setup = state_estimation.mavros_setup:main',
        ],
    },
)
