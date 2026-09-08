# shellcheck shell=bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build preamble: computes the CMake arguments and environment shared by the
# dev build and the wheel builds. Meant to be sourced, not executed directly.
#
# Deliberately activates nothing. A venv activation prepends its own bin/ to
# PATH, which would override the per-pass interpreter that
# build-wheels-manylinux.sh selects for each matrix entry. build-dev.sh, the
# only consumer that wants the dev venv, activates it itself before sourcing
# this file.
#
# Makes available locally:
#   cmake_args     -- extra cmake args for libucxx builds; consumers append
#                     their own (see build-dev.sh for the dev-only Python hints)
#   install_prefix -- the resolved install prefix
#
# Exports:
#   PARALLEL_LEVEL
#   CC, CXX        -- set to hipcc
#   CMAKE_PREFIX_PATH
#
# Required environment variables:
#   INSTALL_DIR, SRC_DIR, ROCM_PATH
#
# Optional environment variables:
#   HIPUCXX_USE_VERSIONS_JSON, SCCACHE_ENABLE, AMDGPU_TARGETS, MAX_JOBS,
#   HIPUCXX_BUILD_TYPE
#   CMAKE_INSTALL_PREFIX -- overrides INSTALL_DIR as the install prefix;
#                           "<conda-prefix>" resolves to CONDA_PREFIX

set -euo pipefail

[[ "${HIPUCXX_USE_VERSIONS_JSON:-"false"}" == "false" ]] && no_use_versions_json=1

[[ "${SCCACHE_ENABLE:-false}" == "true" ]] && use_sccache=1

# Wheel builds resolve rmm and rapids_logger from the ci_packages wheels
# (amd-libhipmm, amd-rocmds-logger) via find_package; libhipcxx rides along in
# amd-libhipmm. A CPM_<pkg>_SOURCE override switches rapids_cpm_find over to
# CPMAddPackage, which skips find_package entirely and builds the dependency
# from /src -- install rules and all -- straight into the wheel.
case "${HIPUCXX_BUILD_TYPE:-}" in
    wheels) wheel_deps_from_pip=1 ;;
esac

use_local_cpm_sources=
if [ -n "${no_use_versions_json:-}" ] && [ -z "${wheel_deps_from_pip:-}" ]; then
    use_local_cpm_sources=1
fi

if [[ "${CMAKE_INSTALL_PREFIX:-}" == "<conda-prefix>" ]]; then
    install_prefix="${CONDA_PREFIX:?CMAKE_INSTALL_PREFIX=<conda-prefix> needs an activated conda env}"
else
    install_prefix="${CMAKE_INSTALL_PREFIX:-${INSTALL_DIR}}"
fi

if [ -n "${AMDGPU_TARGETS:-}" ]; then
    export RAPIDS_CMAKE_HIP_ARCHITECTURES="${AMDGPU_TARGETS}"
fi

# Consumed by the scripts that source this file, not here.
# shellcheck disable=SC2034
cmake_args=(
    "-DCMAKE_VERBOSE_MAKEFILE=ON"
    "-DCMAKE_INSTALL_PREFIX=${install_prefix}"
    "-DUCXX_ENABLE_RMM=ON"
    # CPM honours CPM_<pkg>_SOURCE only as a CMake variable, never from the
    # environment, so these have to stay -D args on the configure line.
    ${use_local_cpm_sources:+"-DCPM_rmm_SOURCE=${SRC_DIR}/hipmm"}
    ${use_local_cpm_sources:+"-DCPM_libhipcxx_SOURCE=${SRC_DIR}/libhipcxx"}
    ${use_local_cpm_sources:+"-DCPM_rapids_logger_SOURCE=${SRC_DIR}/rocmds_logger"}
    ${use_sccache:+"-D CMAKE_HIP_COMPILER_LAUNCHER=sccache"}
    ${use_sccache:+"-D CMAKE_CXX_COMPILER_LAUNCHER=sccache"}
    ${use_sccache:+"-D CMAKE_C_COMPILER_LAUNCHER=sccache"}
)

if [ -d "/opt/rh/gcc-toolset-$(g++ -dumpversion)" ]; then
    toolchain="/opt/rh/gcc-toolset-$(g++ -dumpversion)/root/usr"
    export CCC_OVERRIDE_OPTIONS="+--gcc-toolchain=${toolchain}"
fi

export PARALLEL_LEVEL=${MAX_JOBS:-1}
export CC=hipcc
export CXX=hipcc
export ROCM_HOME="${ROCM_PATH}"
export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:+${CMAKE_PREFIX_PATH}:}${install_prefix}:${ROCM_PATH}"
export CPM_USE_LOCAL_PACKAGES=OFF
export CPM_DOWNLOAD_ALL=OFF
