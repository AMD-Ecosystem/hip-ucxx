# ======================================================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2023-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: BSD-3-Clause AND MIT
# cmake-format: on
# ======================================================================================================

cmake_minimum_required(VERSION 4.0 FATAL_ERROR)

include(../../cmake/rapids_config.cmake)
include(rapids-cmake)
include(rapids-cpm)
include(rapids-export)
include(rapids-find)

file(READ "${CMAKE_CURRENT_LIST_DIR}/../../VERSION" _version_contents)
if(_version_contents MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*$")
  set(libucxx_version "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
else()
  string(REPLACE "\n" "\n  " _version_contents_formatted "${_version_contents}")
  message(
    FATAL_ERROR
      "Could not determine ucxx version. Contents of VERSION file:\n  ${_version_contents_formatted}"
  )
endif()

project(
  UCXX_PYTHON
  VERSION ${libucxx_version}
  LANGUAGES C CXX
)

option(BUILD_SHARED_LIBS "Build UCXX Python shared libraries" ON)

# When built via add_subdirectory() from cpp/, the parent already configured CPM
# and fetched rmm from CPM_rmm_SOURCE (/src/hipmm).
if(NOT UCXX_BUILD_PYTHON_LIB)
  rapids_cpm_init(OVERRIDE ${CMAKE_CURRENT_LIST_DIR}/../../versions.json)
  include(../cmake/thirdparty/get_rmm.cmake)
endif()

# if UCXX_BUILD_PYTHON_LIB is defined, then this is being built as part of the main libucxx project
# itself and the following code path does not apply
if(NOT DEFINED UCXX_BUILD_PYTHON_LIB)
  option(FIND_UCXX_CPP
         "Search for existing UCXX C++ installations before defaulting to local files" OFF
  )
  if(FIND_UCXX_CPP)
    rapids_find_package(
      ucxx REQUIRED
      BUILD_EXPORT_SET ucxx-python-exports
      INSTALL_EXPORT_SET ucxx-python-exports
    )
  else()
    set(UCXX_ENABLE_RMM ON)
    set(UCXX_ENABLE_CCCL ON)
    add_subdirectory(.. ucxx-cpp)
  endif()
endif()

# manylinux CI builds libucxx with a cmake-only venv; never use it for headers.
set(Python3_FIND_VIRTUALENV NEVER)
if(NOT Python3_EXECUTABLE)
  if(DEFINED ENV{HIPUCXX_DEV_ABI})
    set(_py_abi "$ENV{HIPUCXX_DEV_ABI}")
  elseif(DEFINED ENV{PYTHON_ABI})
    set(_py_abi "$ENV{PYTHON_ABI}")
  endif()
  if(DEFINED _py_abi)
    set(_py_root "/opt/python/${_py_abi}")
    if(EXISTS "${_py_root}/bin/python")
      set(Python3_EXECUTABLE "${_py_root}/bin/python" CACHE FILEPATH "" FORCE)
      set(Python3_ROOT_DIR "${_py_root}" CACHE PATH "" FORCE)
    endif()
  endif()
endif()

rapids_find_package(
  Python3 REQUIRED COMPONENTS Development.Module
  BUILD_EXPORT_SET ucxx-python-exports
  INSTALL_EXPORT_SET ucxx-python-exports
)

# ##################################################################################################
# * compiler options ------------------------------------------------------------------------------
rapids_find_package(
  ucx REQUIRED
  BUILD_EXPORT_SET ucxx-exports
  INSTALL_EXPORT_SET ucxx-exports
)

# ##################################################################################################
# * python library --------------------------------------------------------------------------------
add_library(
  ucxx_python src/exception.cpp src/future.cpp src/notifier.cpp src/python_future.cpp
              src/python_future_task_collector.cpp src/worker.cpp
)

set_target_properties(
  ucxx_python
  PROPERTIES BUILD_RPATH "\$ORIGIN"
             INSTALL_RPATH "\$ORIGIN"
             EXPORT_NAME python
             # set target compile options
             CXX_STANDARD 17
             CXX_STANDARD_REQUIRED ON
             POSITION_INDEPENDENT_CODE ON
             INTERFACE_POSITION_INDEPENDENT_CODE ON
)

target_compile_options(ucxx_python PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${UCXX_CXX_FLAGS}>")

get_filename_component(ucxx_dir "${CMAKE_CURRENT_SOURCE_DIR}" DIRECTORY)

# Specify include paths for the current target and dependents
include(GNUInstallDirs)
target_include_directories(
  ucxx_python
  PUBLIC "$<BUILD_INTERFACE:${ucxx_dir}/include>" "$<BUILD_INTERFACE:${ucxx_dir}/python/include>"
  PRIVATE "$<BUILD_INTERFACE:${ucxx_dir}/src>"
  INTERFACE "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
)

target_compile_definitions(ucxx_python PUBLIC "$<$<COMPILE_LANGUAGE:CXX>:${UCXX_CXX_DEFINITIONS}>")

target_compile_definitions(
  ucxx_python PUBLIC UCXX_ENABLE_PYTHON
                     "RMM_LOG_ACTIVE_LEVEL=RAPIDS_LOGGER_LEVEL_${RMM_LOGGING_LEVEL}"
)

if(UCXX_ENABLE_CCCL)
  target_compile_definitions(ucxx_python PUBLIC UCXX_ENABLE_CCCL)
endif()

# Specify the target module library dependencies. We use COMPILE_ONLY for Python because Python does
# not need to be linked since its symbols will always be available at runtime since we are running
# inside the Python interpreter, and setting it up this way ensures that we will work if the
# interpreter links to Python statically instead of dynamically.
target_link_libraries(
  ucxx_python PUBLIC rmm::rmm ucx::ucp ucxx::ucxx "$<COMPILE_ONLY:Python3::Module>"
)

# Add Conda library, and include paths if specified
if(TARGET conda_env)
  target_link_libraries(ucxx_python PRIVATE conda_env)
endif()

add_library(ucxx::python ALIAS ucxx_python)
install(DIRECTORY ${ucxx_dir}/python/include/ucxx DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(
  TARGETS ucxx_python
  DESTINATION ${CMAKE_INSTALL_LIBDIR}
  EXPORT ucxx-python-exports
)

rapids_export(
  INSTALL ucxx-python
  EXPORT_SET ucxx-python-exports
  GLOBAL_TARGETS python
  NAMESPACE ucxx::
)

# ##################################################################################################
# * build export -------------------------------------------------------------------------------
rapids_export(
  BUILD ucxx-python
  EXPORT_SET ucxx-python-exports
  GLOBAL_TARGETS python
  NAMESPACE ucxx::
)
