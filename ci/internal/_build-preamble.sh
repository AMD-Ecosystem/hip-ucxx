# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build preamble: sets up the build environment for hipUCXX.
# Meant to be sourced, not executed directly.
#
# Makes available locally:
#   cmake_args     -- extra cmake args for libucxx builds
#   install_prefix -- the resolved install prefix
#
# Exports:
#   PARALLEL_LEVEL
#   CC, CXX        -- set to hipcc
#   CMAKE_PREFIX_PATH
#
# Required environment variables:
#   INSTALL_DIR, SRC_DIR, BUILD_ARTIFACTS_DIR, ROCM_PATH
#   CMAKE_VERSION
#
# Optional environment variables:
#   HIPUCXX_CONDA_ENV, CONDA_DIR, HIPUCXX_USE_VERSIONS_JSON,
#   SCCACHE_ENABLE, AMDGPU_TARGETS, MAX_JOBS, HIPUCXX_BUILD_TYPE
#   CMAKE_INSTALL_PREFIX -- overrides INSTALL_DIR as the install prefix

set -euo pipefail

_PREAMBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_activate-env.sh
source "${_PREAMBLE_DIR}/_activate-env.sh"

if ! activate_hipucxx_dev_env; then
    python3 --version
    python3 -m venv --clear "${INSTALL_DIR}/venv/hipucxx_dev"
    # shellcheck source=/dev/null
    . "${INSTALL_DIR}/venv/hipucxx_dev/bin/activate"
    pip install --upgrade pip
    pip install "cmake==${CMAKE_VERSION}"
fi
cmake --version && cpack --version

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
    install_prefix="${CONDA_PREFIX}"
else
    install_prefix="${CMAKE_INSTALL_PREFIX:-${INSTALL_DIR}}"
fi

if [ -n "${AMDGPU_TARGETS:-}" ]; then
    export RAPIDS_CMAKE_HIP_ARCHITECTURES="${AMDGPU_TARGETS}"
fi

# manylinux dev headers live under /opt/python/<abi>, not inside hipucxx_dev.
python_abi="${HIPUCXX_DEV_ABI:-${PYTHON_ABI:-cp312-cp312}}"
manylinux_python_root="/opt/python/${python_abi}"
python_cmake_args=()
if [[ -x "${manylinux_python_root}/bin/python" ]]; then
    py_ver="$("${manylinux_python_root}/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    py_inc="${manylinux_python_root}/include/python${py_ver}"
    export CMAKE_INCLUDE_PATH="${py_inc}${CMAKE_INCLUDE_PATH:+:${CMAKE_INCLUDE_PATH}}"
    python_cmake_args=(
        "-DPython3_EXECUTABLE=${manylinux_python_root}/bin/python"
        "-DPython3_ROOT_DIR=${manylinux_python_root}"
        "-DPython3_INCLUDE_DIR=${py_inc}"
        "-DPython3_FIND_VIRTUALENV=NEVER"
    )
fi

cmake_args=(
    "-DCMAKE_VERBOSE_MAKEFILE=ON"
    "-DCPACK_OUTPUT_FILE_PREFIX=${BUILD_ARTIFACTS_DIR}"
    "-DCMAKE_INSTALL_PREFIX=${install_prefix}"
    "-DUCXX_ENABLE_RMM=ON"
    ${use_local_cpm_sources:+"-DCPM_rmm_SOURCE=${SRC_DIR}/hipmm"}
    ${use_local_cpm_sources:+"-DCPM_libhipcxx_SOURCE=${SRC_DIR}/libhipcxx"}
    ${use_local_cpm_sources:+"-DCPM_rapids_logger_SOURCE=${SRC_DIR}/rocmds_logger"}
    ${use_sccache:+"-D CMAKE_HIP_COMPILER_LAUNCHER=sccache"}
    ${use_sccache:+"-D CMAKE_CXX_COMPILER_LAUNCHER=sccache"}
    ${use_sccache:+"-D CMAKE_C_COMPILER_LAUNCHER=sccache"}
    "${python_cmake_args[@]}"
)

if [ -d "/opt/rh/gcc-toolset-$(g++ -dumpversion)" ]; then
    toolchain="/opt/rh/gcc-toolset-$(g++ -dumpversion)/root/usr"
    export CCC_OVERRIDE_OPTIONS="+--gcc-toolchain=${toolchain}"
    export CC=${toolchain}/bin/cc
fi

export PARALLEL_LEVEL=${MAX_JOBS:-1}
export CC=hipcc
export CXX=hipcc
export ROCM_HOME="${ROCM_PATH}"
export CMAKE_PREFIX_PATH+="${install_prefix}:${ROCM_PATH}"
export CPM_USE_LOCAL_PACKAGES=OFF
export CPM_DOWNLOAD_ALL=OFF

export_cpm_sources() {
    if [ -n "${use_local_cpm_sources:-}" ]; then
        export CPM_rmm_SOURCE="${SRC_DIR}/hipmm"
        export CPM_libhipcxx_SOURCE="${SRC_DIR}/libhipcxx"
        export CPM_rapids_logger_SOURCE="${SRC_DIR}/rocmds_logger"
    fi
    export CPM_USE_LOCAL_PACKAGES=OFF
    export CPM_DOWNLOAD_ALL=OFF
}

wheel_cmake_args() {
    # No CPM_*_SOURCE overrides: wheels resolve rmm/rapids_logger from the
    # installed dependency wheels, and UCXX_INSTALL_CPM_DEPS=OFF keeps whatever
    # CPM does fetch out of the wheel's install tree.
    local args=(
        "-DUCXX_ENABLE_RMM=ON"
        "-DUCXX_INSTALL_CPM_DEPS=OFF"
    )
    if ((${#python_cmake_args[@]} > 0)); then
        args+=("${python_cmake_args[@]}")
    fi
    local IFS=';'
    printf '%s' "${args[*]}"
}
