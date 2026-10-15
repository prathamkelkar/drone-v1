from setuptools import find_packages, setup

package_name = 'plan_and_control'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='prathamkelkar',
    maintainer_email='pratham.kel@gmail.com',
    description='Intercept-point solvers that predict where and when the drone can meet a tracked object.',
    license='TODO: License declaration',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'trajectory_predictor_ellipsoid = plan_and_control.trajectory_predictor_ellipsoid:main',
            'trajectory_predictor_independent_axes = plan_and_control.trajectory_predictor_independent_axes:main'
        ],
    },
)
