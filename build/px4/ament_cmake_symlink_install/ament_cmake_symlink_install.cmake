# generated from
# ament_cmake_core/cmake/symlink_install/ament_cmake_symlink_install.cmake.in

# create empty symlink install manifest before starting install step
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/symlink_install_manifest.txt")

#
# Reimplement CMake install(DIRECTORY) command to use symlinks instead of
# copying resources.
#
# :param cmake_current_source_dir: The CMAKE_CURRENT_SOURCE_DIR when install
#   was invoked
# :type cmake_current_source_dir: string
# :param ARGN: the same arguments as the CMake install command.
# :type ARGN: various
#
function(ament_cmake_symlink_install_directory cmake_current_source_dir)
  cmake_parse_arguments(ARG "OPTIONAL" "DESTINATION" "DIRECTORY;PATTERN;PATTERN_EXCLUDE" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "ament_cmake_symlink_install_directory() called with "
      "unused/unsupported arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  # make destination absolute path and ensure that it exists
  if(NOT IS_ABSOLUTE "${ARG_DESTINATION}")
    set(ARG_DESTINATION "/home/prathamkelkar/ros2_ws/install/px4/${ARG_DESTINATION}")
  endif()
  if(NOT EXISTS "${ARG_DESTINATION}")
    file(MAKE_DIRECTORY "${ARG_DESTINATION}")
  endif()

  # default pattern to include
  if(NOT ARG_PATTERN)
    set(ARG_PATTERN "*")
  endif()

  # iterate over directories
  foreach(dir ${ARG_DIRECTORY})
    # make dir an absolute path
    if(NOT IS_ABSOLUTE "${dir}")
      set(dir "${cmake_current_source_dir}/${dir}")
    endif()

    if(EXISTS "${dir}")
      # if directory has no trailing slash
      # append folder name to destination
      set(destination "${ARG_DESTINATION}")
      string(LENGTH "${dir}" length)
      math(EXPR offset "${length} - 1")
      string(SUBSTRING "${dir}" ${offset} 1 dir_last_char)
      if(NOT dir_last_char STREQUAL "/")
        get_filename_component(destination_name "${dir}" NAME)
        set(destination "${destination}/${destination_name}")
      else()
        # remove trailing slash
        string(SUBSTRING "${dir}" 0 ${offset} dir)
      endif()
      
      # Create destination directory.
      # This does *not* solve the problem of empty directories WITHIN the install tree,
      # but does make sure that the top-level directory specified by the caller gets created.
      file(MAKE_DIRECTORY "${destination}")

      # glob recursive files
      set(relative_files "")
      foreach(pattern ${ARG_PATTERN})
        file(
          GLOB_RECURSE
          include_files
          RELATIVE "${dir}"
          "${dir}/${pattern}"
        )
        if(NOT include_files STREQUAL "")
          list(APPEND relative_files ${include_files})
        endif()
      endforeach()
      foreach(pattern ${ARG_PATTERN_EXCLUDE})
        file(
          GLOB_RECURSE
          exclude_files
          RELATIVE "${dir}"
          "${dir}/${pattern}"
        )
        if(NOT exclude_files STREQUAL "")
          list(REMOVE_ITEM relative_files ${exclude_files})
        endif()
      endforeach()
      list(SORT relative_files)

      foreach(relative_file ${relative_files})
        set(absolute_file "${dir}/${relative_file}")
        # determine link name for file including destination path
        set(symlink "${destination}/${relative_file}")

        # ensure that destination exists
        get_filename_component(symlink_dir "${symlink}" PATH)
        if(NOT EXISTS "${symlink_dir}")
          file(MAKE_DIRECTORY "${symlink_dir}")
        endif()

        _ament_cmake_symlink_install_create_symlink("${absolute_file}" "${symlink}")
      endforeach()
    else()
      if(NOT ARG_OPTIONAL)
        message(FATAL_ERROR
          "ament_cmake_symlink_install_directory() can't find '${dir}'")
      endif()
    endif()
  endforeach()
endfunction()

#
# Reimplement CMake install(FILES) command to use symlinks instead of copying
# resources.
#
# :param cmake_current_source_dir: The CMAKE_CURRENT_SOURCE_DIR when install
#   was invoked
# :type cmake_current_source_dir: string
# :param ARGN: the same arguments as the CMake install command.
# :type ARGN: various
#
function(ament_cmake_symlink_install_files cmake_current_source_dir)
  cmake_parse_arguments(ARG "OPTIONAL" "DESTINATION;RENAME" "FILES" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "ament_cmake_symlink_install_files() called with "
      "unused/unsupported arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  # make destination an absolute path and ensure that it exists
  if(NOT IS_ABSOLUTE "${ARG_DESTINATION}")
    set(ARG_DESTINATION "/home/prathamkelkar/ros2_ws/install/px4/${ARG_DESTINATION}")
  endif()
  if(NOT EXISTS "${ARG_DESTINATION}")
    file(MAKE_DIRECTORY "${ARG_DESTINATION}")
  endif()

  if(ARG_RENAME)
    list(LENGTH ARG_FILES file_count)
    if(NOT file_count EQUAL 1)
    message(FATAL_ERROR "ament_cmake_symlink_install_files() called with "
      "RENAME argument but not with a single file")
    endif()
  endif()

  # iterate over files
  foreach(file ${ARG_FILES})
    # make file an absolute path
    if(NOT IS_ABSOLUTE "${file}")
      set(file "${cmake_current_source_dir}/${file}")
    endif()

    if(EXISTS "${file}")
      # determine link name for file including destination path
      get_filename_component(filename "${file}" NAME)
      if(NOT ARG_RENAME)
        set(symlink "${ARG_DESTINATION}/${filename}")
      else()
        set(symlink "${ARG_DESTINATION}/${ARG_RENAME}")
      endif()
      _ament_cmake_symlink_install_create_symlink("${file}" "${symlink}")
    else()
      if(NOT ARG_OPTIONAL)
        message(FATAL_ERROR
          "ament_cmake_symlink_install_files() can't find '${file}'")
      endif()
    endif()
  endforeach()
endfunction()

#
# Reimplement CMake install(PROGRAMS) command to use symlinks instead of copying
# resources.
#
# :param cmake_current_source_dir: The CMAKE_CURRENT_SOURCE_DIR when install
#   was invoked
# :type cmake_current_source_dir: string
# :param ARGN: the same arguments as the CMake install command.
# :type ARGN: various
#
function(ament_cmake_symlink_install_programs cmake_current_source_dir)
  cmake_parse_arguments(ARG "OPTIONAL" "DESTINATION" "PROGRAMS" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "ament_cmake_symlink_install_programs() called with "
      "unused/unsupported arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  # make destination an absolute path and ensure that it exists
  if(NOT IS_ABSOLUTE "${ARG_DESTINATION}")
    set(ARG_DESTINATION "/home/prathamkelkar/ros2_ws/install/px4/${ARG_DESTINATION}")
  endif()
  if(NOT EXISTS "${ARG_DESTINATION}")
    file(MAKE_DIRECTORY "${ARG_DESTINATION}")
  endif()

  # iterate over programs
  foreach(file ${ARG_PROGRAMS})
    # make file an absolute path
    if(NOT IS_ABSOLUTE "${file}")
      set(file "${cmake_current_source_dir}/${file}")
    endif()

    if(EXISTS "${file}")
      # determine link name for file including destination path
      get_filename_component(filename "${file}" NAME)
      set(symlink "${ARG_DESTINATION}/${filename}")
      _ament_cmake_symlink_install_create_symlink("${file}" "${symlink}")
    else()
      if(NOT ARG_OPTIONAL)
        message(FATAL_ERROR
          "ament_cmake_symlink_install_programs() can't find '${file}'")
      endif()
    endif()
  endforeach()
endfunction()

#
# Reimplement CMake install(TARGETS) command to use symlinks instead of copying
# resources.
#
# :param TARGET_FILES: the absolute files, replacing the name of targets passed
#   in as TARGETS
# :type TARGET_FILES: list of files
# :param ARGN: the same arguments as the CMake install command except that
#   keywords identifying the kind of type and the DESTINATION keyword must be
#   joined with an underscore, e.g. ARCHIVE_DESTINATION.
# :type ARGN: various
#
function(ament_cmake_symlink_install_targets)
  cmake_parse_arguments(ARG "OPTIONAL" "ARCHIVE_DESTINATION;DESTINATION;LIBRARY_DESTINATION;RUNTIME_DESTINATION"
    "TARGETS;TARGET_FILES" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "ament_cmake_symlink_install_targets() called with "
      "unused/unsupported arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  # iterate over target files
  foreach(file ${ARG_TARGET_FILES})
    if(NOT IS_ABSOLUTE "${file}")
      message(FATAL_ERROR "ament_cmake_symlink_install_targets() target file "
        "'${file}' must be an absolute path")
    endif()

    # determine destination of file based on extension
    set(destination "")
    get_filename_component(fileext "${file}" EXT)
    if(fileext STREQUAL ".a" OR fileext STREQUAL ".lib")
      set(destination "${ARG_ARCHIVE_DESTINATION}")
    elseif(fileext STREQUAL ".dylib" OR fileext MATCHES "\\.so(\\.[0-9]+)?(\\.[0-9]+)?(\\.[0-9]+)?$")
      set(destination "${ARG_LIBRARY_DESTINATION}")
    elseif(fileext STREQUAL "" OR fileext STREQUAL ".dll" OR fileext STREQUAL ".exe")
      set(destination "${ARG_RUNTIME_DESTINATION}")
    endif()
    if(destination STREQUAL "")
      set(destination "${ARG_DESTINATION}")
    endif()

    # make destination an absolute path and ensure that it exists
    if(NOT IS_ABSOLUTE "${destination}")
      set(destination "/home/prathamkelkar/ros2_ws/install/px4/${destination}")
    endif()
    if(NOT EXISTS "${destination}")
      file(MAKE_DIRECTORY "${destination}")
    endif()

    if(EXISTS "${file}")
      # determine link name for file including destination path
      get_filename_component(filename "${file}" NAME)
      set(symlink "${destination}/${filename}")
      _ament_cmake_symlink_install_create_symlink("${file}" "${symlink}")
    else()
      if(NOT ARG_OPTIONAL)
        message(FATAL_ERROR
          "ament_cmake_symlink_install_targets() can't find '${file}'")
      endif()
    endif()
  endforeach()
endfunction()

function(_ament_cmake_symlink_install_create_symlink absolute_file symlink)
  # register symlink for being removed during install step
  file(APPEND "${CMAKE_CURRENT_BINARY_DIR}/symlink_install_manifest.txt"
    "${symlink}\n")

  # avoid any work if correct symlink is already in place
  if(EXISTS "${symlink}" AND IS_SYMLINK "${symlink}")
    get_filename_component(destination "${symlink}" REALPATH)
    get_filename_component(real_absolute_file "${absolute_file}" REALPATH)
    if(destination STREQUAL real_absolute_file)
      message(STATUS "Up-to-date symlink: ${symlink}")
      return()
    endif()
  endif()

  message(STATUS "Symlinking: ${symlink}")
  if(EXISTS "${symlink}" OR IS_SYMLINK "${symlink}")
    file(REMOVE "${symlink}")
  endif()

  execute_process(
    COMMAND "/usr/bin/cmake" "-E" "create_symlink"
      "${absolute_file}"
      "${symlink}"
  )
  # the CMake command does not provide a return code so check manually
  if(NOT EXISTS "${symlink}" OR NOT IS_SYMLINK "${symlink}")
    get_filename_component(destination "${symlink}" REALPATH)
    message(FATAL_ERROR
      "Could not create symlink '${symlink}' pointing to '${absolute_file}'")
  endif()
endfunction()

# end of template

message(STATUS "Execute custom install script")

# begin of custom install code

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_atomic_hook.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_atomic_hook.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_errno_saver.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_errno_saver.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_severity.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_severity.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_no_destructor.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_no_destructor.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_nullability.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_nullability.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_raw_logging_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_raw_logging_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_spinlock_wait.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_spinlock_wait.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_config.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_config.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_dynamic_annotations.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_dynamic_annotations.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_core_headers.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_core_headers.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_malloc_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_malloc_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_base_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_base_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_base.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_base.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_throw_delegate.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_throw_delegate.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_pretty_function.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_pretty_function.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_endian.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_endian.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_scoped_set_env.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_scoped_set_env.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_strerror.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_strerror.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_fast_type_id.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_fast_type_id.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_prefetch.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_prefetch.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_poison.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_poison.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_tracing_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_tracing_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_iterator_traits_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_iterator_traits_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_iterator_traits_test_helper_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/base" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_iterator_traits_test_helper_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_algorithm.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/algorithm" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_algorithm.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_algorithm_container.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/algorithm" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_algorithm_container.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cleanup_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/cleanup" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cleanup_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cleanup.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/cleanup" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cleanup.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_btree.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_btree.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_compressed_tuple.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_compressed_tuple.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_fixed_array.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_fixed_array.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_inlined_vector_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_inlined_vector_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_inlined_vector.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_inlined_vector.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flat_hash_map.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flat_hash_map.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flat_hash_set.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flat_hash_set.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_node_hash_map.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_node_hash_map.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_node_hash_set.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_node_hash_set.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash_container_defaults.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash_container_defaults.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_container_memory.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_container_memory.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash_function_defaults.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash_function_defaults.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash_policy_traits.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash_policy_traits.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_common_policy_traits.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_common_policy_traits.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtablez_sampler.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtablez_sampler.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtable_debug.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtable_debug.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtable_debug_hooks.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtable_debug_hooks.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_node_slot_policy.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_node_slot_policy.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_raw_hash_map.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_raw_hash_map.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_container_common.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_container_common.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtable_control_bytes.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hashtable_control_bytes.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_raw_hash_set.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_raw_hash_set.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_layout.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/container" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_layout.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc_cpu_detect.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/crc" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc_cpu_detect.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/crc" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc32c.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/crc" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc32c.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_non_temporal_arm_intrinsics.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/crc" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_non_temporal_arm_intrinsics.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_non_temporal_memcpy.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/crc" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_non_temporal_memcpy.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc_cord_state.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/crc" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_crc_cord_state.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_stacktrace.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_stacktrace.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_symbolize.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_symbolize.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_examine_stack.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_examine_stack.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_failure_signal_handler.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_failure_signal_handler.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_debugging_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_debugging_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_demangle_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_demangle_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bounded_utf8_length_sequence.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bounded_utf8_length_sequence.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_decode_rust_punycode.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_decode_rust_punycode.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_demangle_rust.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_demangle_rust.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_utf8_for_code_point.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_utf8_for_code_point.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_leak_check.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_leak_check.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_debugging.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/debugging" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_debugging.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_path_util.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_path_util.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_program_name.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_program_name.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_config.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_config.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_marshalling.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_marshalling.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_commandlineflag_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_commandlineflag_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_commandlineflag.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_commandlineflag.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_private_handle_accessor.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_private_handle_accessor.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_reflection.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_reflection.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_usage_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_usage_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_usage.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_usage.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_parse.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/flags" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_flags_parse.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_any_invocable.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/functional" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_any_invocable.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bind_front.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/functional" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bind_front.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_function_ref.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/functional" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_function_ref.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_overload.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/functional" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_overload.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/hash" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_hash.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_city.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/hash" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_city.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_low_level_hash.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/hash" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_low_level_hash.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_check_impl.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_check_impl.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_check_op.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_check_op.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_conditions.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_conditions.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_config.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_config.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_flags.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_flags.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_format.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_format.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_globals.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_globals.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_log_impl.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_log_impl.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_proto.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_proto.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_message.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_message.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_log_sink_set.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_log_sink_set.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_nullguard.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_nullguard.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_nullstream.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_nullstream.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_strip.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_strip.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_voidify.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_voidify.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_append_truncated.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_append_truncated.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_absl_check.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_absl_check.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_absl_log.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_absl_log.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_check.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_check.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_die_if_null.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_die_if_null.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_flags.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_flags.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_globals.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_globals.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_initialize.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_initialize.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_entry.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_entry.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_sink.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_sink.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_sink_registry.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_sink_registry.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_streamer.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_streamer.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_structured.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_structured.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_structured_proto.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_structured_proto.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_structured.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_structured.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_vlog_config_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_vlog_config_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_absl_vlog_is_on.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_absl_vlog_is_on.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_vlog_is_on.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_vlog_is_on.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_fnmatch.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/log" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_log_internal_fnmatch.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_memory.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/memory" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_memory.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_type_traits.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/meta" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_type_traits.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_meta.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/meta" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_meta.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bits.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/numeric" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bits.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_int128.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/numeric" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_int128.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_numeric.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/numeric" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_numeric.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_numeric_representation.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/numeric" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_numeric_representation.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_sample_recorder.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/profiling" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_sample_recorder.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_exponential_biased.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/profiling" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_exponential_biased.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_periodic_sampler.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/profiling" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_periodic_sampler.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_random.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_random.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_bit_gen_ref.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_bit_gen_ref.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_mock_helpers.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_mock_helpers.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_distributions.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_distributions.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_seed_gen_exception.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_seed_gen_exception.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_seed_sequences.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_seed_sequences.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_traits.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_traits.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_distribution_caller.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_distribution_caller.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_fast_uniform_bits.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_fast_uniform_bits.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_seed_material.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_seed_material.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_entropy_pool.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_entropy_pool.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_salted_seed_seq.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_salted_seed_seq.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_iostream_state_saver.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_iostream_state_saver.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_generate_real.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_generate_real.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_wide_multiply.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_wide_multiply.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_fastmath.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_fastmath.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_nonsecure_base.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_nonsecure_base.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_pcg_engine.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_pcg_engine.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_engine.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_engine.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_platform.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_platform.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_slow.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_slow.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_hwaes.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_hwaes.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_hwaes_impl.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_randen_hwaes_impl.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_distribution_test_util.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_distribution_test_util.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_uniform_helper.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/random" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_random_internal_uniform_helper.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_status.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/status" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_status.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_statusor.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/status" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_statusor.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_string_view.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_string_view.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_strings.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_strings.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_charset.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_charset.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_has_ostream_operator.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_has_ostream_operator.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_strings_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_strings_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_str_format.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_str_format.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_str_format_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_str_format_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cord_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cord_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_update_tracker.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_update_tracker.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_functions.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_functions.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_statistics.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_statistics.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_handle.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_handle.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_info.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_info.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_sample_token.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_sample_token.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_update_scope.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cordz_update_scope.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cord.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/strings" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_cord.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_graphcycles_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/synchronization" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_graphcycles_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_kernel_timeout_internal.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/synchronization" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_kernel_timeout_internal.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_synchronization.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/synchronization" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_synchronization.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_time.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/time" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_time.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_civil_time.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/time" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_civil_time.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_time_zone.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/time" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_time_zone.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_any.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_any.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_span.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_span.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_optional.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_optional.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_variant.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_variant.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_compare.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_compare.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bad_any_cast.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bad_any_cast.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bad_optional_access.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bad_optional_access.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bad_variant_access.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/types" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_bad_variant_access.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_utility.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src/absl/utility" FILES "/home/prathamkelkar/ros2_ws/build/px4/lib/pkgconfig/absl_utility.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-build/abslConfig.cmake" "DESTINATION" "lib/cmake/absl")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src" FILES "/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-build/abslConfig.cmake" "DESTINATION" "lib/cmake/absl")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/options-pinned.h" "DESTINATION" "include/absl/base" "RENAME" "options.h")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/abseil-cpp-src" FILES "/home/prathamkelkar/ros2_ws/build/px4/options-pinned.h" "DESTINATION" "include/absl/base" "RENAME" "options.h")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build/re2Config.cmake" "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build/re2ConfigVersion.cmake" "DESTINATION" "lib/cmake/re2")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-src" FILES "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build/re2Config.cmake" "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build/re2ConfigVersion.cmake" "DESTINATION" "lib/cmake/re2")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build/re2.pc" "DESTINATION" "lib/pkgconfig")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-src" FILES "/home/prathamkelkar/ros2_ws/build/px4/_deps/re2-build/re2.pc" "DESTINATION" "lib/pkgconfig")

# install(FILES "README.md" "VERSION" "DESTINATION" "share/doc/libantlr4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/build/px4/_deps/antlr_cpp-src" FILES "README.md" "VERSION" "DESTINATION" "share/doc/libantlr4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/rosidl_interfaces/px4" "DESTINATION" "share/ament_index/resource_index/rosidl_interfaces")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/rosidl_interfaces/px4" "DESTINATION" "share/ament_index/resource_index/rosidl_interfaces")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActionRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActionRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorArmed.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorArmed.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorControlsStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorControlsStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorOutputs.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorOutputs.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorServosTrim.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorServosTrim.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorTest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorTest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AdcReport.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AdcReport.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Airspeed.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Airspeed.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AirspeedWind.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AirspeedWind.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AutotuneAttitudeControlStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AutotuneAttitudeControlStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/BatteryInfo.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/BatteryInfo.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ButtonEvent.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ButtonEvent.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CameraCapture.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CameraCapture.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CameraStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CameraStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CameraTrigger.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CameraTrigger.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CanInterfaceStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CanInterfaceStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CellularStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CellularStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CollisionConstraints.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/CollisionConstraints.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ControlAllocatorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ControlAllocatorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Cpuload.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Cpuload.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DatamanRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DatamanRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DatamanResponse.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DatamanResponse.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugArray.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugArray.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugKeyValue.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugKeyValue.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugValue.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugValue.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugVect.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DebugVect.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DeviceInformation.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DeviceInformation.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DifferentialPressure.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DifferentialPressure.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DistanceSensor.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DistanceSensor.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DistanceSensorModeChangeRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DistanceSensorModeChangeRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DronecanNodeStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/DronecanNodeStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Ekf2Timestamps.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Ekf2Timestamps.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscEepromRead.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscEepromRead.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscEepromWrite.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscEepromWrite.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscReport.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscReport.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EscStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorAidSource1d.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorAidSource1d.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorAidSource2d.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorAidSource2d.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorAidSource3d.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorAidSource3d.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorBias.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorBias.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorBias3d.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorBias3d.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorEventFlags.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorEventFlags.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorFusionControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorFusionControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorGpsStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorGpsStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorInnovations.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorInnovations.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorSelectorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorSelectorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorSensorBias.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorSensorBias.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorStates.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorStates.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorStatusFlags.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/EstimatorStatusFlags.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FailsafeFlags.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FailsafeFlags.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FailureDetectorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FailureDetectorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FailureInjection.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FailureInjection.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FigureEightStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FigureEightStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLateralGuidanceStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLateralGuidanceStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLateralStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLateralStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingRunwayControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingRunwayControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingTakeoffStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingTakeoffStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FlightPhaseEstimation.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FlightPhaseEstimation.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FollowTarget.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FollowTarget.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FollowTargetEstimator.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FollowTargetEstimator.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FollowTargetStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FollowTargetStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FuelTankStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FuelTankStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GainCompression.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GainCompression.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GeneratorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GeneratorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GeofenceResult.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GeofenceResult.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GeofenceStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GeofenceStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalControls.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalControls.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalDeviceAttitudeStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalDeviceAttitudeStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalDeviceInformation.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalDeviceInformation.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalDeviceSetAttitude.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalDeviceSetAttitude.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerInformation.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerInformation.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerSetAttitude.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerSetAttitude.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerSetManualControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerSetManualControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GimbalManagerStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioConfig.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioConfig.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioIn.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioIn.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioOut.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioOut.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpioRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpsDump.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GpsDump.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Gripper.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Gripper.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HealthReport.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HealthReport.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HeaterStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HeaterStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HoverThrustEstimate.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HoverThrustEstimate.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/InputRc.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/InputRc.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/InternalCombustionEngineControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/InternalCombustionEngineControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/InternalCombustionEngineStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/InternalCombustionEngineStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/IridiumsbdStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/IridiumsbdStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/IrlockReport.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/IrlockReport.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingGear.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingGear.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingGearWheel.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingGearWheel.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingTargetInnovations.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingTargetInnovations.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingTargetPose.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LandingTargetPose.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LaunchDetectionStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LaunchDetectionStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LedControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LedControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LogMessage.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LogMessage.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LoggerStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LoggerStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MagWorkerData.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MagWorkerData.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MagnetometerBiasEstimate.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MagnetometerBiasEstimate.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ManualControlSwitches.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ManualControlSwitches.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MavlinkLog.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MavlinkLog.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MavlinkTunnel.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MavlinkTunnel.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MessageFormatRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MessageFormatRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MessageFormatResponse.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MessageFormatResponse.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Mission.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Mission.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MissionResult.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MissionResult.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MountOrientation.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/MountOrientation.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NavigatorMissionItem.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NavigatorMissionItem.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NavigatorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NavigatorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NeuralControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NeuralControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NfsUp.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NfsUp.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NormalizedUnsignedSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/NormalizedUnsignedSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ObstacleDistance.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ObstacleDistance.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OffboardControlMode.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OffboardControlMode.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OnboardComputerStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OnboardComputerStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdArmStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdArmStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdBasicId.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdBasicId.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdOperatorId.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdOperatorId.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdSelfId.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdSelfId.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdSystem.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OpenDroneIdSystem.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbTest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbTest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbTestLarge.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbTestLarge.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbTestMedium.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbTestMedium.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbitStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/OrbitStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterResetRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterResetRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterSetUsedRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterSetUsedRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterSetValueRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterSetValueRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterSetValueResponse.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterSetValueResponse.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterUpdate.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ParameterUpdate.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Ping.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Ping.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionControllerLandingStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionControllerLandingStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionControllerStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionControllerStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionSetpointTriplet.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PositionSetpointTriplet.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PowerButtonState.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PowerButtonState.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PowerMonitor.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PowerMonitor.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PpsCapture.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PpsCapture.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PurePursuitStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PurePursuitStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PwmInput.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/PwmInput.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Px4ioStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Px4ioStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/QshellReq.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/QshellReq.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/QshellRetval.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/QshellRetval.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RadioStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RadioStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RangingBeacon.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RangingBeacon.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RateCtrlStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RateCtrlStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RcChannels.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RcChannels.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RcParameterMap.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RcParameterMap.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverAttitudeSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverAttitudeSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverAttitudeStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverAttitudeStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverPositionSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverPositionSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverRateSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverRateSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverRateStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverRateStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverSpeedSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverSpeedSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverSpeedStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverSpeedStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverSteeringSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverSteeringSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverThrottleSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RoverThrottleSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Rpm.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Rpm.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RtcmData.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RtcmData.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RtlStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RtlStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RtlTimeEstimate.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RtlTimeEstimate.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SatelliteInfo.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SatelliteInfo.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorAccel.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorAccel.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorAccelFifo.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorAccelFifo.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorAirflow.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorAirflow.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorBaro.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorBaro.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorCombined.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorCombined.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorCorrection.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorCorrection.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGnssRelative.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGnssRelative.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGnssStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGnssStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGps.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGps.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGyro.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGyro.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGyroFft.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGyroFft.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGyroFifo.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorGyroFifo.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorHygrometer.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorHygrometer.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorMag.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorMag.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorOpticalFlow.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorOpticalFlow.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorPreflightMag.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorPreflightMag.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorSelection.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorSelection.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorTemp.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorTemp.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorUwb.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorUwb.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorsStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorsStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorsStatusImu.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SensorsStatusImu.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SystemPower.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SystemPower.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TakeoffStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TakeoffStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TaskStackInfo.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TaskStackInfo.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TecsStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TecsStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TelemetryStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TelemetryStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TiltrotorExtraControls.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TiltrotorExtraControls.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TimesyncStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TimesyncStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TrajectorySetpoint6dof.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TrajectorySetpoint6dof.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TransponderReport.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TransponderReport.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TuneControl.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TuneControl.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UavcanFirmwareUpdate.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UavcanFirmwareUpdate.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UavcanParameterRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UavcanParameterRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UavcanParameterValue.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UavcanParameterValue.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UlogStream.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UlogStream.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UlogStreamAck.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UlogStreamAck.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAcceleration.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAcceleration.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAirData.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAirData.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleConstraints.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleConstraints.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleControlMode.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleControlMode.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleImu.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleImu.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleImuStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleImuStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleLocalPositionSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleLocalPositionSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleMagnetometer.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleMagnetometer.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleOpticalFlow.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleOpticalFlow.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleOpticalFlowVel.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleOpticalFlowVel.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleRoi.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleRoi.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleThrustSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleThrustSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleTorqueSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleTorqueSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VelocityLimits.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VelocityLimits.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Vtx.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Vtx.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/WheelEncoders.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/WheelEncoders.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/YawEstimatorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/YawEstimatorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorMotors.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorMotors.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorServos.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ActuatorServos.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AirspeedValidated.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AirspeedValidated.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ArmingCheckReply.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ArmingCheckReply.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ArmingCheckRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ArmingCheckRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AuxGlobalPosition.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/AuxGlobalPosition.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/BatteryStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/BatteryStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ConfigOverrides.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ConfigOverrides.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Event.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Event.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLateralSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLateralSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLongitudinalSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/FixedWingLongitudinalSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GotoSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/GotoSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HomePosition.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/HomePosition.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LateralControlConfiguration.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LateralControlConfiguration.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LongitudinalControlConfiguration.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/LongitudinalControlConfiguration.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ManualControlSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ManualControlSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ModeCompleted.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/ModeCompleted.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RaptorInput.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RaptorInput.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RaptorStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RaptorStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RegisterExtComponentReply.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RegisterExtComponentReply.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RegisterExtComponentRequest.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/RegisterExtComponentRequest.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SetpointConfig.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SetpointConfig.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SetpointConfigReply.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/SetpointConfigReply.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TrajectorySetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/TrajectorySetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UnregisterExtComponent.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/UnregisterExtComponent.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAngularVelocity.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAngularVelocity.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAttitude.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAttitude.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAttitudeSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleAttitudeSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleCommand.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleCommand.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleCommandAck.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleCommandAck.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleGlobalPosition.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleGlobalPosition.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleLandDetected.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleLandDetected.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleLocalPosition.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleLocalPosition.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleOdometry.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleOdometry.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleRatesSetpoint.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleRatesSetpoint.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VehicleStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VtolVehicleStatus.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/VtolVehicleStatus.json" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Wind.json" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_type_description/px4/msg/Wind.json" "DESTINATION" "share/px4/msg")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_c/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.h")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_c/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.h")

# install(FILES "/opt/ros/jazzy/lib/python3.12/site-packages/ament_package/template/environment_hook/library_path.sh" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/opt/ros/jazzy/lib/python3.12/site-packages/ament_package/template/environment_hook/library_path.sh" "DESTINATION" "share/px4/environment")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_environment_hooks/library_path.dsv" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_environment_hooks/library_path.dsv" "DESTINATION" "share/px4/environment")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_fastrtps_c/px4/" "DESTINATION" "include/px4/px4" "PATTERN_EXCLUDE" "*.cpp")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_fastrtps_c/px4/" "DESTINATION" "include/px4/px4" "PATTERN_EXCLUDE" "*.cpp")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_cpp/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.hpp")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_cpp/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.hpp")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_fastrtps_cpp/px4/" "DESTINATION" "include/px4/px4" "PATTERN_EXCLUDE" "*.cpp")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_fastrtps_cpp/px4/" "DESTINATION" "include/px4/px4" "PATTERN_EXCLUDE" "*.cpp")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_introspection_c/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.h")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_introspection_c/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.h")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_introspection_cpp/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.hpp")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_typesupport_introspection_cpp/px4/" "DESTINATION" "include/px4/px4" "PATTERN" "*.hpp")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_environment_hooks/pythonpath.sh" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_environment_hooks/pythonpath.sh" "DESTINATION" "share/px4/environment")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_environment_hooks/pythonpath.dsv" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_environment_hooks/pythonpath.dsv" "DESTINATION" "share/px4/environment")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_python/px4/px4.egg-info/" "DESTINATION" "lib/python3.12/site-packages/px4-1.14.0-py3.12.egg-info")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_python/px4/px4.egg-info/" "DESTINATION" "lib/python3.12/site-packages/px4-1.14.0-py3.12.egg-info")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_py/px4/" "DESTINATION" "lib/python3.12/site-packages/px4" "PATTERN_EXCLUDE" "*.pyc" "PATTERN_EXCLUDE" "__pycache__")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_py/px4/" "DESTINATION" "lib/python3.12/site-packages/px4" "PATTERN_EXCLUDE" "*.pyc" "PATTERN_EXCLUDE" "__pycache__")

# install("TARGETS" "px4_s__rosidl_typesupport_fastrtps_c" "DESTINATION" "lib/python3.12/site-packages/px4")
include("/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_symlink_install_targets_0_${CMAKE_INSTALL_CONFIG_NAME}.cmake")

# install("TARGETS" "px4_s__rosidl_typesupport_introspection_c" "DESTINATION" "lib/python3.12/site-packages/px4")
include("/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_symlink_install_targets_1_${CMAKE_INSTALL_CONFIG_NAME}.cmake")

# install("TARGETS" "px4_s__rosidl_typesupport_c" "DESTINATION" "lib/python3.12/site-packages/px4")
include("/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/ament_cmake_symlink_install_targets_2_${CMAKE_INSTALL_CONFIG_NAME}.cmake")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/rust_packages/px4" "DESTINATION" "share/ament_index/resource_index/rust_packages")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/rust_packages/px4" "DESTINATION" "share/ament_index/resource_index/rust_packages")

# install(DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_rs/px4/rust" "DESTINATION" "share/px4")
ament_cmake_symlink_install_directory("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" DIRECTORY "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_generator_rs/px4/rust" "DESTINATION" "share/px4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActionRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActionRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorArmed.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorArmed.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorControlsStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorControlsStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorOutputs.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorOutputs.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorServosTrim.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorServosTrim.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorTest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorTest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AdcReport.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AdcReport.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Airspeed.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Airspeed.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AirspeedWind.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AirspeedWind.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AutotuneAttitudeControlStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AutotuneAttitudeControlStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/BatteryInfo.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/BatteryInfo.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ButtonEvent.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ButtonEvent.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CameraCapture.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CameraCapture.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CameraStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CameraStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CameraTrigger.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CameraTrigger.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CanInterfaceStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CanInterfaceStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CellularStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CellularStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CollisionConstraints.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/CollisionConstraints.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ControlAllocatorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ControlAllocatorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Cpuload.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Cpuload.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DatamanRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DatamanRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DatamanResponse.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DatamanResponse.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugArray.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugArray.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugKeyValue.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugKeyValue.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugValue.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugValue.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugVect.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DebugVect.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DeviceInformation.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DeviceInformation.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DifferentialPressure.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DifferentialPressure.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DistanceSensor.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DistanceSensor.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DistanceSensorModeChangeRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DistanceSensorModeChangeRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DronecanNodeStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/DronecanNodeStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Ekf2Timestamps.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Ekf2Timestamps.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscEepromRead.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscEepromRead.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscEepromWrite.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscEepromWrite.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscReport.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscReport.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EscStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorAidSource1d.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorAidSource1d.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorAidSource2d.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorAidSource2d.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorAidSource3d.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorAidSource3d.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorBias.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorBias.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorBias3d.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorBias3d.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorEventFlags.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorEventFlags.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorFusionControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorFusionControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorGpsStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorGpsStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorInnovations.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorInnovations.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorSelectorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorSelectorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorSensorBias.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorSensorBias.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorStates.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorStates.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorStatusFlags.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/EstimatorStatusFlags.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FailsafeFlags.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FailsafeFlags.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FailureDetectorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FailureDetectorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FailureInjection.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FailureInjection.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FigureEightStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FigureEightStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLateralGuidanceStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLateralGuidanceStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLateralStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLateralStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingRunwayControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingRunwayControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingTakeoffStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingTakeoffStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FlightPhaseEstimation.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FlightPhaseEstimation.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FollowTarget.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FollowTarget.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FollowTargetEstimator.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FollowTargetEstimator.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FollowTargetStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FollowTargetStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FuelTankStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FuelTankStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GainCompression.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GainCompression.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GeneratorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GeneratorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GeofenceResult.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GeofenceResult.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GeofenceStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GeofenceStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalControls.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalControls.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalDeviceAttitudeStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalDeviceAttitudeStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalDeviceInformation.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalDeviceInformation.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalDeviceSetAttitude.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalDeviceSetAttitude.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerInformation.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerInformation.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerSetAttitude.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerSetAttitude.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerSetManualControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerSetManualControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GimbalManagerStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioConfig.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioConfig.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioIn.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioIn.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioOut.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioOut.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpioRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpsDump.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GpsDump.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Gripper.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Gripper.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HealthReport.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HealthReport.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HeaterStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HeaterStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HoverThrustEstimate.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HoverThrustEstimate.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/InputRc.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/InputRc.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/InternalCombustionEngineControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/InternalCombustionEngineControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/InternalCombustionEngineStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/InternalCombustionEngineStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/IridiumsbdStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/IridiumsbdStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/IrlockReport.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/IrlockReport.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingGear.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingGear.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingGearWheel.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingGearWheel.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingTargetInnovations.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingTargetInnovations.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingTargetPose.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LandingTargetPose.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LaunchDetectionStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LaunchDetectionStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LedControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LedControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LogMessage.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LogMessage.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LoggerStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LoggerStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MagWorkerData.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MagWorkerData.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MagnetometerBiasEstimate.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MagnetometerBiasEstimate.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ManualControlSwitches.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ManualControlSwitches.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MavlinkLog.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MavlinkLog.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MavlinkTunnel.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MavlinkTunnel.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MessageFormatRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MessageFormatRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MessageFormatResponse.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MessageFormatResponse.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Mission.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Mission.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MissionResult.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MissionResult.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MountOrientation.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/MountOrientation.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NavigatorMissionItem.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NavigatorMissionItem.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NavigatorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NavigatorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NeuralControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NeuralControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NfsUp.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NfsUp.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NormalizedUnsignedSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/NormalizedUnsignedSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ObstacleDistance.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ObstacleDistance.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OffboardControlMode.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OffboardControlMode.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OnboardComputerStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OnboardComputerStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdArmStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdArmStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdBasicId.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdBasicId.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdOperatorId.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdOperatorId.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdSelfId.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdSelfId.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdSystem.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OpenDroneIdSystem.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbTest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbTest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbTestLarge.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbTestLarge.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbTestMedium.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbTestMedium.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbitStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/OrbitStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterResetRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterResetRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterSetUsedRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterSetUsedRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterSetValueRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterSetValueRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterSetValueResponse.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterSetValueResponse.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterUpdate.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ParameterUpdate.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Ping.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Ping.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionControllerLandingStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionControllerLandingStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionControllerStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionControllerStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionSetpointTriplet.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PositionSetpointTriplet.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PowerButtonState.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PowerButtonState.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PowerMonitor.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PowerMonitor.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PpsCapture.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PpsCapture.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PurePursuitStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PurePursuitStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PwmInput.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/PwmInput.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Px4ioStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Px4ioStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/QshellReq.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/QshellReq.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/QshellRetval.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/QshellRetval.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RadioStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RadioStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RangingBeacon.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RangingBeacon.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RateCtrlStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RateCtrlStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RcChannels.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RcChannels.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RcParameterMap.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RcParameterMap.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverAttitudeSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverAttitudeSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverAttitudeStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverAttitudeStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverPositionSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverPositionSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverRateSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverRateSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverRateStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverRateStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverSpeedSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverSpeedSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverSpeedStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverSpeedStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverSteeringSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverSteeringSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverThrottleSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RoverThrottleSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Rpm.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Rpm.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RtcmData.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RtcmData.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RtlStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RtlStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RtlTimeEstimate.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RtlTimeEstimate.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SatelliteInfo.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SatelliteInfo.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorAccel.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorAccel.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorAccelFifo.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorAccelFifo.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorAirflow.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorAirflow.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorBaro.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorBaro.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorCombined.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorCombined.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorCorrection.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorCorrection.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGnssRelative.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGnssRelative.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGnssStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGnssStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGps.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGps.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGyro.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGyro.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGyroFft.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGyroFft.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGyroFifo.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorGyroFifo.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorHygrometer.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorHygrometer.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorMag.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorMag.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorOpticalFlow.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorOpticalFlow.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorPreflightMag.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorPreflightMag.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorSelection.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorSelection.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorTemp.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorTemp.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorUwb.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorUwb.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorsStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorsStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorsStatusImu.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SensorsStatusImu.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SystemPower.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SystemPower.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TakeoffStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TakeoffStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TaskStackInfo.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TaskStackInfo.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TecsStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TecsStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TelemetryStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TelemetryStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TiltrotorExtraControls.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TiltrotorExtraControls.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TimesyncStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TimesyncStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TrajectorySetpoint6dof.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TrajectorySetpoint6dof.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TransponderReport.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TransponderReport.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TuneControl.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TuneControl.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UavcanFirmwareUpdate.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UavcanFirmwareUpdate.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UavcanParameterRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UavcanParameterRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UavcanParameterValue.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UavcanParameterValue.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UlogStream.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UlogStream.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UlogStreamAck.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UlogStreamAck.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAcceleration.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAcceleration.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAirData.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAirData.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleConstraints.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleConstraints.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleControlMode.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleControlMode.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleImu.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleImu.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleImuStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleImuStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleLocalPositionSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleLocalPositionSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleMagnetometer.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleMagnetometer.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleOpticalFlow.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleOpticalFlow.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleOpticalFlowVel.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleOpticalFlowVel.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleRoi.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleRoi.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleThrustSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleThrustSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleTorqueSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleTorqueSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VelocityLimits.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VelocityLimits.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Vtx.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Vtx.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/WheelEncoders.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/WheelEncoders.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/YawEstimatorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/YawEstimatorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorMotors.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorMotors.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorServos.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ActuatorServos.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AirspeedValidated.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AirspeedValidated.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ArmingCheckReply.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ArmingCheckReply.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ArmingCheckRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ArmingCheckRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AuxGlobalPosition.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/AuxGlobalPosition.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/BatteryStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/BatteryStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ConfigOverrides.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ConfigOverrides.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Event.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Event.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLateralSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLateralSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLongitudinalSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/FixedWingLongitudinalSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GotoSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/GotoSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HomePosition.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/HomePosition.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LateralControlConfiguration.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LateralControlConfiguration.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LongitudinalControlConfiguration.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/LongitudinalControlConfiguration.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ManualControlSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ManualControlSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ModeCompleted.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/ModeCompleted.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RaptorInput.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RaptorInput.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RaptorStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RaptorStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RegisterExtComponentReply.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RegisterExtComponentReply.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RegisterExtComponentRequest.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/RegisterExtComponentRequest.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SetpointConfig.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SetpointConfig.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SetpointConfigReply.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/SetpointConfigReply.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TrajectorySetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/TrajectorySetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UnregisterExtComponent.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/UnregisterExtComponent.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAngularVelocity.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAngularVelocity.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAttitude.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAttitude.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAttitudeSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleAttitudeSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleCommand.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleCommand.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleCommandAck.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleCommandAck.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleGlobalPosition.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleGlobalPosition.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleLandDetected.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleLandDetected.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleLocalPosition.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleLocalPosition.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleOdometry.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleOdometry.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleRatesSetpoint.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleRatesSetpoint.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VehicleStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VtolVehicleStatus.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/VtolVehicleStatus.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Wind.idl" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/build/px4/platforms/ros2/rosidl_adapter/px4/msg/Wind.idl" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActionRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActionRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorArmed.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorArmed.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorControlsStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorControlsStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorOutputs.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorOutputs.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorServosTrim.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorServosTrim.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorTest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ActuatorTest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/AdcReport.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/AdcReport.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Airspeed.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Airspeed.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/AirspeedWind.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/AirspeedWind.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/AutotuneAttitudeControlStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/AutotuneAttitudeControlStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/BatteryInfo.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/BatteryInfo.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ButtonEvent.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ButtonEvent.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CameraCapture.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CameraCapture.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CameraStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CameraStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CameraTrigger.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CameraTrigger.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CanInterfaceStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CanInterfaceStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CellularStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CellularStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CollisionConstraints.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/CollisionConstraints.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ControlAllocatorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ControlAllocatorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Cpuload.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Cpuload.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DatamanRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DatamanRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DatamanResponse.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DatamanResponse.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugArray.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugArray.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugKeyValue.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugKeyValue.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugValue.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugValue.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugVect.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DebugVect.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DeviceInformation.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DeviceInformation.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DifferentialPressure.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DifferentialPressure.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DistanceSensor.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DistanceSensor.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DistanceSensorModeChangeRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DistanceSensorModeChangeRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DronecanNodeStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/DronecanNodeStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Ekf2Timestamps.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Ekf2Timestamps.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscEepromRead.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscEepromRead.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscEepromWrite.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscEepromWrite.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscReport.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscReport.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EscStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorAidSource1d.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorAidSource1d.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorAidSource2d.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorAidSource2d.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorAidSource3d.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorAidSource3d.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorBias.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorBias.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorBias3d.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorBias3d.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorEventFlags.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorEventFlags.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorFusionControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorFusionControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorGpsStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorGpsStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorInnovations.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorInnovations.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorSelectorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorSelectorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorSensorBias.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorSensorBias.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorStates.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorStates.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorStatusFlags.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/EstimatorStatusFlags.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FailsafeFlags.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FailsafeFlags.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FailureDetectorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FailureDetectorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FailureInjection.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FailureInjection.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FigureEightStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FigureEightStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingLateralGuidanceStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingLateralGuidanceStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingLateralStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingLateralStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingRunwayControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingRunwayControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingTakeoffStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FixedWingTakeoffStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FlightPhaseEstimation.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FlightPhaseEstimation.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FollowTarget.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FollowTarget.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FollowTargetEstimator.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FollowTargetEstimator.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FollowTargetStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FollowTargetStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FuelTankStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/FuelTankStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GainCompression.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GainCompression.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GeneratorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GeneratorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GeofenceResult.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GeofenceResult.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GeofenceStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GeofenceStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalControls.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalControls.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalDeviceAttitudeStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalDeviceAttitudeStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalDeviceInformation.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalDeviceInformation.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalDeviceSetAttitude.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalDeviceSetAttitude.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerInformation.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerInformation.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerSetAttitude.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerSetAttitude.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerSetManualControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerSetManualControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GimbalManagerStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioConfig.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioConfig.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioIn.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioIn.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioOut.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioOut.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpioRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpsDump.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/GpsDump.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Gripper.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Gripper.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/HealthReport.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/HealthReport.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/HeaterStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/HeaterStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/HoverThrustEstimate.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/HoverThrustEstimate.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/InputRc.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/InputRc.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/InternalCombustionEngineControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/InternalCombustionEngineControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/InternalCombustionEngineStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/InternalCombustionEngineStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/IridiumsbdStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/IridiumsbdStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/IrlockReport.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/IrlockReport.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingGear.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingGear.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingGearWheel.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingGearWheel.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingTargetInnovations.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingTargetInnovations.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingTargetPose.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LandingTargetPose.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LaunchDetectionStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LaunchDetectionStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LedControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LedControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LogMessage.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LogMessage.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LoggerStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/LoggerStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MagWorkerData.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MagWorkerData.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MagnetometerBiasEstimate.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MagnetometerBiasEstimate.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ManualControlSwitches.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ManualControlSwitches.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MavlinkLog.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MavlinkLog.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MavlinkTunnel.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MavlinkTunnel.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MessageFormatRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MessageFormatRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MessageFormatResponse.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MessageFormatResponse.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Mission.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Mission.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MissionResult.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MissionResult.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MountOrientation.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/MountOrientation.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NavigatorMissionItem.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NavigatorMissionItem.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NavigatorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NavigatorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NeuralControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NeuralControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NfsUp.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NfsUp.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NormalizedUnsignedSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/NormalizedUnsignedSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ObstacleDistance.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ObstacleDistance.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OffboardControlMode.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OffboardControlMode.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OnboardComputerStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OnboardComputerStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdArmStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdArmStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdBasicId.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdBasicId.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdOperatorId.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdOperatorId.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdSelfId.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdSelfId.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdSystem.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OpenDroneIdSystem.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbTest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbTest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbTestLarge.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbTestLarge.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbTestMedium.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbTestMedium.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbitStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/OrbitStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterResetRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterResetRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterSetUsedRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterSetUsedRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterSetValueRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterSetValueRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterSetValueResponse.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterSetValueResponse.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterUpdate.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/ParameterUpdate.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Ping.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Ping.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionControllerLandingStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionControllerLandingStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionControllerStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionControllerStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionSetpointTriplet.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PositionSetpointTriplet.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PowerButtonState.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PowerButtonState.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PowerMonitor.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PowerMonitor.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PpsCapture.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PpsCapture.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PurePursuitStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PurePursuitStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PwmInput.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/PwmInput.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Px4ioStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Px4ioStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/QshellReq.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/QshellReq.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/QshellRetval.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/QshellRetval.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RadioStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RadioStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RangingBeacon.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RangingBeacon.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RateCtrlStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RateCtrlStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RcChannels.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RcChannels.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RcParameterMap.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RcParameterMap.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverAttitudeSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverAttitudeSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverAttitudeStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverAttitudeStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverPositionSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverPositionSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverRateSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverRateSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverRateStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverRateStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverSpeedSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverSpeedSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverSpeedStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverSpeedStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverSteeringSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverSteeringSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverThrottleSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RoverThrottleSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Rpm.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Rpm.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RtcmData.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RtcmData.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RtlStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RtlStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RtlTimeEstimate.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/RtlTimeEstimate.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SatelliteInfo.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SatelliteInfo.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorAccel.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorAccel.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorAccelFifo.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorAccelFifo.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorAirflow.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorAirflow.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorBaro.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorBaro.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorCombined.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorCombined.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorCorrection.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorCorrection.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGnssRelative.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGnssRelative.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGnssStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGnssStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGps.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGps.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGyro.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGyro.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGyroFft.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGyroFft.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGyroFifo.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorGyroFifo.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorHygrometer.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorHygrometer.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorMag.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorMag.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorOpticalFlow.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorOpticalFlow.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorPreflightMag.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorPreflightMag.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorSelection.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorSelection.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorTemp.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorTemp.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorUwb.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorUwb.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorsStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorsStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorsStatusImu.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SensorsStatusImu.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SystemPower.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/SystemPower.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TakeoffStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TakeoffStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TaskStackInfo.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TaskStackInfo.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TecsStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TecsStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TelemetryStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TelemetryStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TiltrotorExtraControls.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TiltrotorExtraControls.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TimesyncStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TimesyncStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TrajectorySetpoint6dof.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TrajectorySetpoint6dof.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TransponderReport.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TransponderReport.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TuneControl.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/TuneControl.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UavcanFirmwareUpdate.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UavcanFirmwareUpdate.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UavcanParameterRequest.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UavcanParameterRequest.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UavcanParameterValue.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UavcanParameterValue.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UlogStream.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UlogStream.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UlogStreamAck.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/UlogStreamAck.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleAcceleration.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleAcceleration.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleAirData.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleAirData.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleConstraints.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleConstraints.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleControlMode.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleControlMode.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleImu.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleImu.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleImuStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleImuStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleLocalPositionSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleLocalPositionSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleMagnetometer.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleMagnetometer.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleOpticalFlow.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleOpticalFlow.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleOpticalFlowVel.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleOpticalFlowVel.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleRoi.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleRoi.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleThrustSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleThrustSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleTorqueSetpoint.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VehicleTorqueSetpoint.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VelocityLimits.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/VelocityLimits.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Vtx.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/Vtx.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/WheelEncoders.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/WheelEncoders.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/YawEstimatorStatus.msg" "DESTINATION" "share/px4/msg")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/YawEstimatorStatus.msg" "DESTINATION" "share/px4/msg")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ActuatorMotors.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ActuatorMotors.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ActuatorServos.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ActuatorServos.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/AirspeedValidated.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/AirspeedValidated.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ArmingCheckReply.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ArmingCheckReply.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ArmingCheckRequest.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ArmingCheckRequest.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/AuxGlobalPosition.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/AuxGlobalPosition.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/BatteryStatus.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/BatteryStatus.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ConfigOverrides.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ConfigOverrides.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/Event.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/Event.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/FixedWingLateralSetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/FixedWingLateralSetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/FixedWingLongitudinalSetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/FixedWingLongitudinalSetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/GotoSetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/GotoSetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/HomePosition.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/HomePosition.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/LateralControlConfiguration.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/LateralControlConfiguration.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/LongitudinalControlConfiguration.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/LongitudinalControlConfiguration.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ManualControlSetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ManualControlSetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ModeCompleted.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/ModeCompleted.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RaptorInput.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RaptorInput.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RaptorStatus.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RaptorStatus.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RegisterExtComponentReply.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RegisterExtComponentReply.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RegisterExtComponentRequest.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/RegisterExtComponentRequest.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/SetpointConfig.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/SetpointConfig.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/SetpointConfigReply.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/SetpointConfigReply.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/TrajectorySetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/TrajectorySetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/UnregisterExtComponent.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/UnregisterExtComponent.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleAngularVelocity.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleAngularVelocity.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleAttitude.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleAttitude.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleAttitudeSetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleAttitudeSetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleCommand.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleCommand.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleCommandAck.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleCommandAck.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleGlobalPosition.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleGlobalPosition.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleLandDetected.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleLandDetected.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleLocalPosition.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleLocalPosition.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleOdometry.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleOdometry.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleRatesSetpoint.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleRatesSetpoint.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleStatus.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VehicleStatus.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VtolVehicleStatus.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/VtolVehicleStatus.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/Wind.msg" "DESTINATION" "share/px4/versioned")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/platforms/ros2/../../msg/versioned/Wind.msg" "DESTINATION" "share/px4/versioned")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/package_run_dependencies/px4" "DESTINATION" "share/ament_index/resource_index/package_run_dependencies")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/package_run_dependencies/px4" "DESTINATION" "share/ament_index/resource_index/package_run_dependencies")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/parent_prefix_path/px4" "DESTINATION" "share/ament_index/resource_index/parent_prefix_path")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/parent_prefix_path/px4" "DESTINATION" "share/ament_index/resource_index/parent_prefix_path")

# install(FILES "/opt/ros/jazzy/share/ament_cmake_core/cmake/environment_hooks/environment/ament_prefix_path.sh" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/opt/ros/jazzy/share/ament_cmake_core/cmake/environment_hooks/environment/ament_prefix_path.sh" "DESTINATION" "share/px4/environment")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/ament_prefix_path.dsv" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/ament_prefix_path.dsv" "DESTINATION" "share/px4/environment")

# install(FILES "/opt/ros/jazzy/share/ament_cmake_core/cmake/environment_hooks/environment/path.sh" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/opt/ros/jazzy/share/ament_cmake_core/cmake/environment_hooks/environment/path.sh" "DESTINATION" "share/px4/environment")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/path.dsv" "DESTINATION" "share/px4/environment")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/path.dsv" "DESTINATION" "share/px4/environment")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.bash" "DESTINATION" "share/px4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.bash" "DESTINATION" "share/px4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.sh" "DESTINATION" "share/px4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.sh" "DESTINATION" "share/px4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.zsh" "DESTINATION" "share/px4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.zsh" "DESTINATION" "share/px4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.dsv" "DESTINATION" "share/px4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/local_setup.dsv" "DESTINATION" "share/px4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/package.dsv" "DESTINATION" "share/px4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_environment_hooks/package.dsv" "DESTINATION" "share/px4")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/packages/px4" "DESTINATION" "share/ament_index/resource_index/packages")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_index/share/ament_index/resource_index/packages/px4" "DESTINATION" "share/ament_index/resource_index/packages")

# install(FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_core/px4Config.cmake" "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_core/px4Config-version.cmake" "DESTINATION" "share/px4/cmake")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_core/px4Config.cmake" "/home/prathamkelkar/ros2_ws/build/px4/ament_cmake_core/px4Config-version.cmake" "DESTINATION" "share/px4/cmake")

# install(FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/package.xml" "DESTINATION" "share/px4")
ament_cmake_symlink_install_files("/home/prathamkelkar/ros2_ws/PX4-Autopilot" FILES "/home/prathamkelkar/ros2_ws/PX4-Autopilot/package.xml" "DESTINATION" "share/px4")
