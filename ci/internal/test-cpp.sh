#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Run C++ tests/examples/benchmarks selected via HIPUCXX_TARGETS (cxx_* tokens).

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_activate-env.sh
. "${SCRIPT_DIR}/_activate-env.sh"
# shellcheck source=_install-artifact-deps.sh
. "${SCRIPT_DIR}/_install-artifact-deps.sh"

install_cpp_packages_from_artifacts

src_dir="${SRC_DIR}/${PROJECT_ID}"
build_dir="${BUILD_DIR}/${PROJECT_ID}"

run_targets=()
if hipucxx_has_target cxx_tests; then
    run_targets+=(cpp_tests)
fi
if hipucxx_has_target cxx_ex; then
    run_targets+=(cpp_examples)
fi
if hipucxx_has_target cxx_bench; then
    run_targets+=(cpp_bench)
fi

if [ ${#run_targets[@]} -eq 0 ]; then
    echo "No cxx_* targets in HIPUCXX_TARGETS; nothing to run."
    exit 0
fi

ulimit -n 65536

cd "${src_dir}"
./run.hip.sh --build-dir "${build_dir}" "${run_targets[@]}"
