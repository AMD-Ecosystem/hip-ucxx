#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Run Python tests/benchmarks selected via HIPUCXX_TARGETS (py_* tokens).

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_package-utils.sh
. "${SCRIPT_DIR}/_package-utils.sh"

activate_python_environment

setup_build_environment

pip install pytest pytest-timeout
install_python_wheels_from_artifacts
pip install --find-links "${BUILD_ARTIFACTS_DIR}" \
    "${BUILD_ARTIFACTS_DIR}"/amd_libhipucxx*.whl \
    "$(echo ${BUILD_ARTIFACTS_DIR}/amd_hipucxx*.whl)[test]" \
    "${BUILD_ARTIFACTS_DIR}"/amd_distributed_hipucxx*.whl

src_dir="${SRC_DIR}/${PROJECT_ID}"
build_dir="${BUILD_DIR}/${PROJECT_ID}"

run_targets=()
if hipucxx_has_target py_tests; then
    run_targets+=(py_tests py_async_tests cython_tests)
fi
if hipucxx_has_target py_bench; then
    run_targets+=(py_bench py_async_bench)
fi

if [ ${#run_targets[@]} -eq 0 ]; then
    echo "No py_* targets in HIPUCXX_TARGETS; nothing to run."
    exit 0
fi

# Python tests throw this error with the default ulimit:
# UCX  ERROR accept() failed (client addr <>): the maximal number of files that could be opened
# simultaneously was reached, try to increase the limit by setting the max open files limit
# (ulimit -n) to a greater value (current: 1024)
ulimit -n 65536

cd "${src_dir}"
./run.hip.sh --build-dir "${build_dir}" "${run_targets[@]}"
