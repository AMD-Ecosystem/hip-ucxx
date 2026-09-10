#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build hipUCXX Python wheels (amd-libhipucxx, amd-hipucxx, amd-distributed-hipucxx).
#
# Required environment variables:
#   PROJECT_ID, SRC_DIR, BUILD_DIR, INSTALL_DIR, BUILD_ARTIFACTS_DIR
#   AMDGPU_TARGETS, ROCM_PATH
#
# Optional environment variables:
#   HIPUCXX_BUILD_TYPE, CMAKE_VERSION
#   UCXX_VERSION -- pins the wheels this build installs from BUILD_ARTIFACTS_DIR
#   CMAKE_INSTALL_PREFIX -- overrides INSTALL_DIR as the install prefix
#   USE_SABI -- "no", or the CPython version to use as the stable-ABI (abi3)
#               floor for amd-hipucxx, e.g. "3.12". Only "no" builds today:
#               ucxx/_lib/arr.pyx cimports PyMemoryView_GET_BUFFER and
#               PyTuple_SET_ITEM, neither of which the limited API declares in
#               any CPython version, so a floor fails the compile outright.
#   HIPUCXX_BUILD_LIBHIPUCXX, HIPUCXX_BUILD_UCXX, HIPUCXX_BUILD_DISTRIBUTED --
#               each wheel is built unless its switch is set empty.

set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_wheel-helpers.sh
source "${SCRIPT_DIR}/_wheel-helpers.sh"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${AMDGPU_TARGETS:?AMDGPU_TARGETS must be set}"
: "${ROCM_PATH:?ROCM_PATH must be set}"

build_libhipucxx=${HIPUCXX_BUILD_LIBHIPUCXX-1}
build_ucxx=${HIPUCXX_BUILD_UCXX-1}
build_distributed=${HIPUCXX_BUILD_DISTRIBUTED-1}

if [ "${USE_SABI:-no}" = "no" ]; then
    ucxx_wheel_config=("--config-settings=skbuild.wheel.py-api=")
else
    ucxx_wheel_config=("--config-settings=skbuild.wheel.py-api=cp${USE_SABI//./}")
fi

src_dir=${SRC_DIR}/${PROJECT_ID}
wheels_build_dir=${BUILD_DIR}/_WHEELS_/
build_dir="${wheels_build_dir}/${PROJECT_ID}"

mkdir -p "${wheels_build_dir}"
cp -va "${src_dir}/." "${build_dir}/"

cd "${build_dir}"
# shellcheck source=_build-preamble.sh
. "${SCRIPT_DIR}/_build-preamble.sh"

# cmake_args comes from _build-preamble.sh, which shellcheck cannot read when
# this script is checked on its own.
# shellcheck disable=SC2154
SKBUILD_CMAKE_ARGS="$(IFS=';'; echo "${cmake_args[*]}")"
export SKBUILD_CMAKE_ARGS
export WHEEL_BUILD_ROOT="${build_dir}"

setup_build_environment
# libhipcxx is a dependency to build the Python wheels
_install_artifact_package libhipcxx

export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm-ds"
wheels_build_env=$(mktemp -d)
python3 -m venv "${wheels_build_env}"
# shellcheck source=/dev/null
. "${wheels_build_env}/bin/activate"

    # shellcheck source=_install-build-deps.sh
    . "${SCRIPT_DIR}/_install-build-deps.sh"

    # No CPM_*_SOURCE overrides: wheels resolve rmm/rapids_logger from the
    # installed dependency wheels, and UCXX_INSTALL_CPM_DEPS=OFF keeps whatever
    # CPM does fetch out of the wheel's install tree.
    #
    # No Python_* hints either: scikit-build-core owns interpreter resolution
    # per matrix pass.
    wheel_cmake_args=(
        "-DUCXX_ENABLE_RMM=ON"
        "-DUCXX_INSTALL_CPM_DEPS=OFF"
    )
    wheel_cmake="$(IFS=';'; echo "${wheel_cmake_args[*]}")"

# SRC_DIR, BUILD_DIR, and PROJECT_ID are provided by the CI environment
# (not assigned in this repo); fail fast with a clear message if they are unset.
: "${SRC_DIR:?SRC_DIR must be set by the CI environment}"
: "${BUILD_DIR:?BUILD_DIR must be set by the CI environment}"
: "${PROJECT_ID:?PROJECT_ID must be set by the CI environment}"

# shellcheck disable=SC2153  # SRC_DIR is a CI env var, not a typo of src_dir
src_dir="${SRC_DIR}/${PROJECT_ID}"
# shellcheck disable=SC2153  # BUILD_DIR is a CI env var, not a typo of build_dir
build_dir="${BUILD_DIR}/${PROJECT_ID}"
install_prefix="${CMAKE_INSTALL_PREFIX:-${INSTALL_DIR}/${PROJECT_ID}}"

if [ -n "${HIPUCXX_WHEEL_REQUIREMENTS:-}" ]; then
    pip install -r "${HIPUCXX_WHEEL_REQUIREMENTS}"
fi

read -ra wheel_targets <<< "${HIPUCXX_WHEEL_TARGETS:-py-all}"
build_args=("${wheel_targets[@]}" -n)
    if [ -n "${build_libhipucxx}" ]; then
        build_rapids_wheel "python/libucxx" "${wheel_cmake}"
        verify_wheel_absent 'amd_libhipucxx*.whl' 'rapids_logger|librapids|rmm/|librmm|libhipmm'
    fi

    if [ -n "${build_ucxx}" ]; then
        # note: load-bearing -- FIND_UCXX_CPP=ON makes cpp/python take the rapids_find_package(ucxx)
        # branch, which resolves against this wheel instead of recompiling the C++ library here.
        install_built_wheel --no-deps --no-index -- \
            "amd_libhipucxx${UCXX_VERSION:+==${UCXX_VERSION}}"
        build_rapids_wheel "python/ucxx" "${wheel_cmake};-DFIND_UCXX_CPP=ON" "${ucxx_wheel_config[@]}"
        # The Cython module is ucxx/_lib/libucxx.cpython-*.so, so this only catches a bundled
        # C++ libucxx.so[.N] -- i.e. FIND_UCXX_CPP silently falling back to the source build.
        verify_wheel_absent 'amd_hipucxx*.whl' 'libucxx\.so'
    fi

    if [ -n "${build_distributed}" ]; then
        build_setuptools_wheel "python/distributed-ucxx"
    fi

deactivate
rm -rf "${wheels_build_env}"

rm -rf "${build_dir}"
