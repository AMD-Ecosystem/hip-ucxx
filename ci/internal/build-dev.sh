#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build and install libucxx (C++), then CPack to BUILD_ARTIFACTS_DIR.

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${ROCM_PATH:?ROCM_PATH must be set}"

# shellcheck source=_activate-env.sh
. "${SCRIPT_DIR}/_activate-env.sh"

# Activate before sourcing the preamble: it resolves install_prefix from
# CONDA_PREFIX when CMAKE_INSTALL_PREFIX is "<conda-prefix>".
activate_hipucxx_python_environment

# shellcheck source=_build-preamble.sh
. "${SCRIPT_DIR}/_build-preamble.sh"

pip install packaging

src_dir="${SRC_DIR}/${PROJECT_ID}"
build_dir="${BUILD_DIR}/${PROJECT_ID}"
install_prefix="${CMAKE_INSTALL_PREFIX:-${INSTALL_DIR}/${PROJECT_ID}}"
tests_tarball_name="${PROJECT_ID}-tests.tar.gz"

case "${CI_INTERNAL_CREATE_TESTS_TARBALL:-0}" in
    1 | true | yes | on) create_tests_tarball="1" ;;
    *) create_tests_tarball="" ;;
esac

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

# CPack runs from this script only, never from a wheel build.
# cmake_args comes from _build-preamble.sh, which shellcheck cannot read when
# this script is checked on its own.
# shellcheck disable=SC2154
cmake_args+=("-DCPACK_OUTPUT_FILE_PREFIX=${BUILD_ARTIFACTS_DIR}")

# Point CMake at the manylinux dev headers under /opt/python/<abi>: this build
# configures cpp/python with the cmake-only hipucxx_dev venv active, and that
# venv carries no Python headers. Wheel builds need none of this, because
# scikit-build-core supplies the hints itself, one interpreter per matrix pass.
python_abi="${HIPUCXX_DEV_ABI:-${PYTHON_ABI:-cp312-cp312}}"
manylinux_python_root="/opt/python/${python_abi}"
if [[ -x "${manylinux_python_root}/bin/python" ]]; then
    py_ver="$("${manylinux_python_root}/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    py_inc="${manylinux_python_root}/include/python${py_ver}"
    export CMAKE_INCLUDE_PATH="${py_inc}${CMAKE_INCLUDE_PATH:+:${CMAKE_INCLUDE_PATH}}"
    cmake_args+=(
        "-DPython_EXECUTABLE=${manylinux_python_root}/bin/python"
        "-DPython_ROOT_DIR=${manylinux_python_root}"
        "-DPython_INCLUDE_DIR=${py_inc}"
        "-DPython_FIND_VIRTUALENV=NEVER"
    )
fi

if [[ "${#cmake_args[@]}" -gt 0 ]]; then
    build_args+=(--cmake-args="${cmake_args[*]}")
fi

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

if [ -n "${create_tests_tarball:-}" ]; then
    dev_venv="${INSTALL_DIR}/venv/hipucxx_dev"
    [ -d "${dev_venv}" ] || dev_venv=""

    tar_args=("${src_dir#/}" "${build_dir#/}")
    if [ -n "${dev_venv}" ]; then
        tar_args+=("${dev_venv#/}")
    fi

    tar --exclude=.git -czf "${BUILD_ARTIFACTS_DIR}/${tests_tarball_name}" \
        -C / "${tar_args[@]}"
    du -sh "${BUILD_ARTIFACTS_DIR}/${tests_tarball_name}"
fi
