# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2018-2025, NVIDIA CORPORATION.
# SPDX-License-Identifier: BSD-3-Clause
# cmake-format: on
# =============================================================================
# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: Apache-2.0 AND MIT
# =============================================================================

file(READ "${CMAKE_CURRENT_LIST_DIR}/../ROCmDS_VERSION" _rocmds_version)
if(_rocmds_version MATCHES [[^([0-9][0-9])\.([0-9][0-9])\.([0-9][0-9])]])
  set(ROCmDS_VERSION_MAJOR "${CMAKE_MATCH_1}")
  set(ROCmDS_VERSION_MINOR "${CMAKE_MATCH_2}")
  set(ROCmDS_VERSION_PATCH "${CMAKE_MATCH_3}")
  set(ROCmDS_VERSION_MAJOR_MINOR "${ROCmDS_VERSION_MAJOR}.${ROCmDS_VERSION_MINOR}")
  set(ROCmDS_VERSION "${ROCmDS_VERSION_MAJOR}.${ROCmDS_VERSION_MINOR}.${ROCmDS_VERSION_PATCH}")
else()
  string(REPLACE "\n" "\n  " _rocmds_version_formatted "  ${_rocmds_version}")
  message(
    FATAL_ERROR
      "Could not determine ROCmDS version. Contents of ROCmDS_VERSION file:\n${_rocmds_version_formatted}"
  )
endif()

# <<<<<<< OLD CODE from 2c080795 (dfc637ef) - COMMENTED OUT
# set(RAPIDS_CMAKE_MODULE_PATH
#     $ENV{RAPIDS_CMAKE_MODULE_PATH}
#     CACHE FILEPATH "Announce that ROCmDS-CMake is available via the provided module path."
# )
#
# if(NOT "${RAPIDS_CMAKE_MODULE_PATH}" STREQUAL "")
#   list(APPEND CMAKE_MODULE_PATH "${RAPIDS_CMAKE_MODULE_PATH}")
#   # NOTE(HIP/AMD): Set rapids-cmake-dir variable
#   set(rapids-cmake-dir "${RAPIDS_CMAKE_MODULE_PATH}")
#   include(rapids-cmake)
#   return()
# endif()
#
# set(rapids-cmake-version "${ROCmDS_VERSION_MAJOR_MINOR}")
# =======
# Use STRINGS to trim whitespace/newlines
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/../RAPIDS_BRANCH" _rapids_branch)
if(NOT _rapids_branch)
  message(
    FATAL_ERROR
      "Could not determine branch name to use for checking out rapids-cmake. The file \"${CMAKE_CURRENT_LIST_DIR}/../RAPIDS_BRANCH\" is missing."
  )
endif()

if(NOT rapids-cmake-version)
  set(rapids-cmake-version "${RAPIDS_VERSION_MAJOR_MINOR}")
endif()
if(NOT rapids-cmake-branch)
  set(rapids-cmake-branch "${_rapids_branch}")
endif()
# >>>>>>> END NEW CODE (dfc637ef)
include("${CMAKE_CURRENT_LIST_DIR}/RAPIDS.cmake")

# Don't use sccache-dist for CMake's compiler tests
set(ENV{SCCACHE_NO_DIST_COMPILE} "1")
