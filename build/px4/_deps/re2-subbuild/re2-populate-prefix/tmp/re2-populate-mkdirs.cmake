# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-src"
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build"
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix"
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix/tmp"
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix/src/re2-populate-stamp"
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix/src"
  "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix/src/re2-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix/src/re2-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-subbuild/re2-populate-prefix/src/re2-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
