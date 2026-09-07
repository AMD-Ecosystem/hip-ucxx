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
#   SCCACHE_ENABLE, AMDGPU_TARGETS, MAX_JOBS
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
    python_cmake_args=(
        "-DPython3_EXECUTABLE=${manylinux_python_root}/bin/python"
        "-DPython3_ROOT_DIR=${manylinux_python_root}"
    )
fi

cmake_args=(
    "-DCMAKE_VERBOSE_MAKEFILE=ON"
    "-DCPACK_OUTPUT_FILE_PREFIX=${BUILD_ARTIFACTS_DIR}"
    "-DCMAKE_INSTALL_PREFIX=${install_prefix}"
    "-DUCXX_ENABLE_RMM=ON"
    ${no_use_versions_json:+"-DCPM_rmm_SOURCE=${SRC_DIR}/hipmm"}
    ${no_use_versions_json:+"-DCPM_libhipcxx_SOURCE=${SRC_DIR}/libhipcxx"}
    ${no_use_versions_json:+"-DCPM_rapids_logger_SOURCE=${SRC_DIR}/rocmds_logger"}
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
    if [[ "${HIPUCXX_USE_VERSIONS_JSON:-"false"}" == "false" ]]; then
        export CPM_rmm_SOURCE="${SRC_DIR}/hipmm"
        export CPM_libhipcxx_SOURCE="${SRC_DIR}/libhipcxx"
        export CPM_rapids_logger_SOURCE="${SRC_DIR}/rocmds_logger"
    fi
    export CPM_USE_LOCAL_PACKAGES=OFF
    export CPM_DOWNLOAD_ALL=OFF
}

wheel_cmake_args() {
    printf '%s' "-DUCXX_ENABLE_RMM=ON;-DCPM_rmm_SOURCE=${SRC_DIR}/hipmm;-DCPM_libhipcxx_SOURCE=${SRC_DIR}/libhipcxx;-DCPM_rapids_logger_SOURCE=${SRC_DIR}/rocmds_logger"
}
