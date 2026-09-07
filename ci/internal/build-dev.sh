#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build and install libucxx (C++), then CPack to BUILD_ARTIFACTS_DIR.

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_build-preamble.sh
. "${SCRIPT_DIR}/_build-preamble.sh"
# shellcheck source=_install-artifact-deps.sh
. "${SCRIPT_DIR}/_install-artifact-deps.sh"

activate_hipucxx_python_environment

setup_build_environment
pip install packaging

install_cpp_packages_from_artifacts

src_dir="${SRC_DIR}/${PROJECT_ID}"
build_dir="${BUILD_DIR}/${PROJECT_ID}"
install_prefix="${CMAKE_INSTALL_PREFIX:-${INSTALL_DIR}/${PROJECT_ID}}"

build_args=(libucxx)
if hipucxx_has_target cxx_tests; then
    build_args+=(libucxx-tests)
fi
if hipucxx_has_target cxx_ex; then
    build_args+=(libucxx-ex)
fi
if hipucxx_has_target cxx_bench; then
    build_args+=(libucxx-bench)
fi
if hipucxx_has_target cxx_py_api; then
    build_args+=(libucxx-py-api)
fi

[[ "${HIPUCXX_DEBUG_BUILD:-false}" == "true" ]] && build_args+=(-g)

if [ -n "${HIPUCXX_GPU_ARCHS:-}" ]; then
    build_args+=(--gpu-archs "${HIPUCXX_GPU_ARCHS}")
elif [ -n "${AMDGPU_TARGETS:-}" ]; then
    build_args+=(--gpu-archs "${AMDGPU_TARGETS}")
fi

build_args+=(
    --build-dir "${build_dir}"
    --install-prefix "${install_prefix}"
)

cd "${src_dir}"
./build.hip.sh "${build_args[@]}"

libucxx_build_dir="${build_dir}/cpp/build"
if [ -d "${libucxx_build_dir}" ]; then
    pkg_fmt=$(package_format)
    mkdir -p "${BUILD_ARTIFACTS_DIR}"
    cmake "${libucxx_build_dir}" \
        -DCPACK_GENERATOR="${pkg_fmt}" \
        -DCPACK_OUTPUT_FILE_PREFIX="${BUILD_ARTIFACTS_DIR}"
    cmake --build "${libucxx_build_dir}" --target package
fi
