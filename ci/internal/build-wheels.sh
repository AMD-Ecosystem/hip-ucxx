#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build Python wheels and copy them to BUILD_ARTIFACTS_DIR.
#
# Optional environment variables:
#   HIPUCXX_WHEEL_TARGETS -- build.hip.sh targets to build (default: py-all)
#   HIPUCXX_WHEEL_PY_API  -- wheel.py-api for the ucxx wheel; a CPython tag such
#                            as cp312 builds against the stable ABI, an empty
#                            value clears any pin. Unset leaves it to the
#                            pyproject files.
#   HIPUCXX_WHEEL_PLATFORM_RETAG -- when 1, replace the generic linux_x86_64
#                            platform tag with the manylinux tag auditwheel
#                            reports. Only meaningful in a manylinux image.
#   HIPUCXX_WHEEL_REQUIREMENTS -- pip requirements file with the build-time
#                            dependencies whose versions the caller pins, the
#                            hip-python and hipMM wheels ucxx/_lib cimports
#                            among them. Images that carry those pins, rather
#                            than pooling the wheels in BUILD_ARTIFACTS_DIR,
#                            hand them over this way.

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_build-preamble.sh
. "${SCRIPT_DIR}/_build-preamble.sh"
# shellcheck source=_install-artifact-deps.sh
. "${SCRIPT_DIR}/_install-artifact-deps.sh"
# shellcheck source=_wheel-helpers.sh
. "${SCRIPT_DIR}/_wheel-helpers.sh"

activate_hipucxx_python_environment

setup_build_environment
# libhipcxx is a dependency to build the Python wheels
_install_artifact_package libhipcxx

export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm-ds"

pip install wheel build Cython scikit-build-core setuptools packaging

install_python_wheels_from_artifacts

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

[[ "${HIPUCXX_DEBUG_BUILD:-false}" == "true" ]] && build_args+=(-g)

if [ -n "${HIPUCXX_GPU_ARCHS:-}" ]; then
    build_args+=(--gpu-archs "${HIPUCXX_GPU_ARCHS}")
elif [ -n "${AMDGPU_TARGETS:-}" ]; then
    build_args+=(--gpu-archs "${AMDGPU_TARGETS}")
fi

# Set, not just non-empty: an empty value clears a pyproject pin.
if [ -n "${HIPUCXX_WHEEL_PY_API+set}" ]; then
    build_args+=(--py-api "${HIPUCXX_WHEEL_PY_API}")
fi

build_args+=(
    --build-dir "${build_dir}"
    --install-prefix "${install_prefix}"
)

cd "${src_dir}"
./build.hip.sh "${build_args[@]}"

wheel_dir="${build_dir}/python/dist"
if [ -d "${wheel_dir}" ] && compgen -G "${wheel_dir}/*.whl" > /dev/null; then
    mkdir -p "${BUILD_ARTIFACTS_DIR}"
    cp -v "${wheel_dir}"/*.whl "${BUILD_ARTIFACTS_DIR}/"
fi

if [[ "${HIPUCXX_WHEEL_PLATFORM_RETAG:-0}" == "1" ]]; then
    retag_linux_wheels
fi
