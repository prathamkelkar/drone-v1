from setuptools import find_packages, setup

package_name = 'perception'

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
    description='YOLO-based single-object detector publishing vision_msgs/Detection2D.',
    license='TODO: License declaration',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'perception_node = perception.perception_node:main',
            'perception_without_nn = perception.perception_without_nn:main'
        ],
    },
)
