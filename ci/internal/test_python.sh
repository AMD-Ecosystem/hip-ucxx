#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Run Python tests/benchmarks selected via HIPUCXX_TARGETS (py_* tokens).
#
# Optional environment variables:
#   HIPUCXX_TEST_REQUIREMENTS -- pip requirements file with the third-party test
#                            dependencies. Images that pin those versions
#                            themselves, rather than pooling them as wheels in
#                            BUILD_ARTIFACTS_DIR, hand them over this way.

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_package-utils.sh
. "${SCRIPT_DIR}/_package-utils.sh"

activate_python_environment

setup_build_environment

pip install pytest pytest-timeout
install_python_wheels_from_artifacts

if [ -n "${HIPUCXX_TEST_REQUIREMENTS:-}" ]; then
    pip install -r "${HIPUCXX_TEST_REQUIREMENTS}"
fi

# By distribution rather than by file, so this interpreter takes the wheel
# tagged for it out of a pool that may cover several, instead of pip rejecting a
# file it was handed.
specs=()
shopt -s nullglob
for wheel in "${BUILD_ARTIFACTS_DIR}"/*hipucxx*.whl; do
    # {name}-{version}-{optional build tag}-{python}-{abi}-{platform}.whl
    IFS=- read -r dist version _ <<< "$(basename "${wheel}")"
    [[ "${dist}" == "amd_hipucxx" ]] && dist="amd_hipucxx[test]"
    specs+=("${dist}==${version}")
done
shopt -u nullglob

if [ ${#specs[@]} -eq 0 ]; then
    echo "ERROR: no hipUCXX wheels in ${BUILD_ARTIFACTS_DIR}; nothing to test." >&2
    exit 1
fi

# Each distribution named once, however many tags the pool holds for it.
mapfile -t specs < <(printf '%s\n' "${specs[@]}" | sort -u)

pip install --find-links "${BUILD_ARTIFACTS_DIR}" "${specs[@]}"

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
