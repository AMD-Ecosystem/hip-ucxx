#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Run Python tests/benchmarks selected via HIPUCXX_TARGETS (py_* tokens).
#
# Required environment variables:
#   PROJECT_ID, BUILD_DIR, BUILD_ARTIFACTS_DIR, ARTIFACTS_DIR
#
# Optional environment variables:
#   HIPUCXX_TEST_RESULTS_SUFFIX -- appended to the pytest output dir name
#   UCXX_VERSION -- pins the hipUCXX wheels installed from BUILD_ARTIFACTS_DIR

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR must be set}"

# shellcheck source=_activate-env.sh
. "${SCRIPT_DIR}/_activate-env.sh"
# shellcheck source=_install-test-deps.sh
. "${SCRIPT_DIR}/_install-test-deps.sh"
# shellcheck source=_wheel-helpers.sh
. "${SCRIPT_DIR}/_wheel-helpers.sh"

wheels_test_env=$(mktemp -d)
python3 -m venv "${wheels_test_env}"
# shellcheck source=/dev/null
. "${wheels_test_env}/bin/activate"

pip install --upgrade pip

# No --no-index here, unlike the build: this install resolves the wheels'
# own runtime dependencies for real.
install_built_wheel -- \
    "amd_libhipucxx${UCXX_VERSION:+==${UCXX_VERSION}}" \
    "amd_hipucxx[test]${UCXX_VERSION:+==${UCXX_VERSION}}" \
    "amd_distributed_hipucxx${UCXX_VERSION:+==${UCXX_VERSION}}"

src_dir="${SRC_DIR:-/src}/${PROJECT_ID}"
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
    deactivate
    rm -rf "${wheels_test_env}"
    exit 0
fi

ulimit -n 65536

cd "${src_dir}"
./run.hip.sh --build-dir "${build_dir}" "${run_targets[@]}"

deactivate
rm -rf "${wheels_test_env}"
