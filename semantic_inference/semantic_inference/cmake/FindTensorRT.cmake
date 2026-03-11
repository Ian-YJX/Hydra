# FindTensorRT.cmake
#
# Robust CMake find-module for NVIDIA TensorRT.
#
# Provides:
#   TensorRT_FOUND
#   TensorRT_VERSION
#   TensorRT_INCLUDE_DIRS
#   TensorRT_LIBRARIES
#
# Imported targets (if found):
#   TensorRT::TensorRT
#   TensorRT::onnxparser         (optional component)
#   TensorRT::infer_plugin       (optional component, maps to nvinfer_plugin)
#
# Components supported:
#   onnxparser
#   infer_plugin
#
# Notes:
#   - This module is designed to be tolerant: it will NOT crash if a component
#     is missing; it will simply not provide that imported target.
#   - It is compatible with typical Ubuntu installs where libraries are in:
#       /usr/lib/x86_64-linux-gnu
#     and headers in:
#       /usr/include/x86_64-linux-gnu or /usr/include

include(FindPackageHandleStandardArgs)

# ----------------------------
# 1) Core include + library
# ----------------------------

find_path(TensorRT_INCLUDE_DIR
  NAMES NvInfer.h
  HINTS
    /usr/include
    /usr/include/x86_64-linux-gnu
    /usr/local/include
    /usr/local/include/x86_64-linux-gnu
)

find_library(TensorRT_LIBRARY
  NAMES nvinfer
  HINTS
    /usr/lib
    /usr/lib/x86_64-linux-gnu
    /usr/local/lib
    /usr/local/lib/x86_64-linux-gnu
)

# ----------------------------
# 2) Parse version (optional)
# ----------------------------

set(TensorRT_VERSION "")

if(TensorRT_INCLUDE_DIR AND EXISTS "${TensorRT_INCLUDE_DIR}/NvInferVersion.h")
  file(READ "${TensorRT_INCLUDE_DIR}/NvInferVersion.h" _tensorrt_version_file)

  set(_VERSION_ITEMS "")
  foreach(_arg IN ITEMS MAJOR MINOR PATCH BUILD)
    set(_REGEX_STRING "#define[ \t]+NV_TENSORRT_${_arg}[ \t]+([0-9]+)[^\n]*\n")
    string(REGEX MATCH "${_REGEX_STRING}" _line_match "${_tensorrt_version_file}")
    if(_line_match)
      list(APPEND _VERSION_ITEMS "${CMAKE_MATCH_1}")
    endif()
  endforeach()

  if(_VERSION_ITEMS)
    list(JOIN _VERSION_ITEMS "." TensorRT_VERSION)
  endif()
endif()

# ----------------------------
# 3) Handle components
# ----------------------------

set(TensorRT_COMPONENT_LIBRARIES "")

# Only attempt components if the core include dir exists
# (prevents the crash you saw: INTERFACE_INCLUDE_DIRECTORIES empty)
if(TensorRT_INCLUDE_DIR)

  foreach(component IN LISTS TensorRT_FIND_COMPONENTS)

    # Map component name -> actual library filename
    # The user passes: infer_plugin, but the library is nvinfer_plugin
    if(component STREQUAL "infer_plugin")
      set(_libname "nvinfer_plugin")
    elseif(component STREQUAL "onnxparser")
      set(_libname "nvonnxparser")
    else()
      # Fallback: try nv<component> (keeps compatibility with custom components)
      set(_libname "nv${component}")
    endif()

    find_library(TensorRT_${component}_LIBRARY
      NAMES "${_libname}"
      HINTS
        /usr/lib
        /usr/lib/x86_64-linux-gnu
        /usr/local/lib
        /usr/local/lib/x86_64-linux-gnu
    )

    if(TensorRT_${component}_LIBRARY)
      set(TensorRT_${component}_FOUND TRUE)

      # Create imported target
      if(NOT TARGET TensorRT::${component})
        add_library(TensorRT::${component} UNKNOWN IMPORTED)
      endif()

      set_target_properties(TensorRT::${component} PROPERTIES
        IMPORTED_LOCATION "${TensorRT_${component}_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${TensorRT_INCLUDE_DIR}"
      )

      list(APPEND TensorRT_COMPONENT_LIBRARIES TensorRT::${component})
    else()
      set(TensorRT_${component}_FOUND FALSE)
    endif()

  endforeach()

endif()

# ----------------------------
# 4) Standard args + summary
# ----------------------------

find_package_handle_standard_args(
  TensorRT
  REQUIRED_VARS TensorRT_LIBRARY TensorRT_INCLUDE_DIR
  VERSION_VAR TensorRT_VERSION
  HANDLE_COMPONENTS
)

# ----------------------------
# 5) Export vars + imported core target
# ----------------------------

if(TensorRT_FOUND)
  mark_as_advanced(TensorRT_INCLUDE_DIR TensorRT_LIBRARY)

  set(TensorRT_LIBRARIES "${TensorRT_LIBRARY}")
  set(TensorRT_INCLUDE_DIRS "${TensorRT_INCLUDE_DIR}")

  if(NOT TARGET TensorRT::TensorRT)
    add_library(TensorRT::TensorRT UNKNOWN IMPORTED)
  endif()

  # INTERFACE_LINK_LIBRARIES must not be empty-string
  if(TensorRT_COMPONENT_LIBRARIES)
    set(_tensorrt_interface_links "${TensorRT_COMPONENT_LIBRARIES}")
  else()
    set(_tensorrt_interface_links "")
  endif()

  set_target_properties(TensorRT::TensorRT PROPERTIES
    IMPORTED_LOCATION "${TensorRT_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${TensorRT_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${_tensorrt_interface_links}"
  )

  # Optional version property
  if(TensorRT_VERSION)
    set_property(TARGET TensorRT::TensorRT PROPERTY VERSION "${TensorRT_VERSION}")
  endif()

endif()
