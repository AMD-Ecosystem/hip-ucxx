# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2020-2025, NVIDIA CORPORATION.
# SPDX-License-Identifier: BSD-3-Clause
# cmake-format: on
# =============================================================================

# This function finds rmm and sets any additional necessary environment variables.
function(find_and_configure_rmm)
  include(${rapids-cmake-dir}/cpm/rmm.cmake)

  # When UCXX_INSTALL_CPM_DEPS is off, an rmm built by CPM must not contribute install rules of its
  # own (it would drag rmm and its transitive rapids_logger into our install tree). EXCLUDE_FROM_ALL
  # suppresses those rules, and INSTALL_EXPORT_SET must be dropped along with them.
  set(_export_sets BUILD_EXPORT_SET ucxx-exports)
  set(_exclude_flag)
  if(UCXX_INSTALL_CPM_DEPS)
    list(APPEND _export_sets INSTALL_EXPORT_SET ucxx-exports)
  else()
    set(_exclude_flag EXCLUDE_FROM_ALL)
  endif()

  # Find or install RMM
  rapids_cpm_rmm(${_export_sets} ${_exclude_flag})

  # rmm is still a link dependency of the installed ucxx, so consumers of the installed config need
  # to be able to find it even though we did not install it ourselves.
  if(NOT UCXX_INSTALL_CPM_DEPS)
    include(${rapids-cmake-dir}/export/package.cmake)
    rapids_export_package(INSTALL rmm ucxx-exports VERSION ${rmm_VERSION})
  endif()

endfunction()

find_and_configure_rmm()
