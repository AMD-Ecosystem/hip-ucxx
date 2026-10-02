#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Run C++ tests/examples/benchmarks selected via HIPUCXX_TARGETS (cxx_* tokens).

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_activate-env.sh
. "${SCRIPT_DIR}/_activate-env.sh"

: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"

if ! activate_hipucxx_dev_env; then
    # shellcheck source=/dev/null
    . "${INSTALL_DIR}/venv/hipucxx_dev/bin/activate"
fi

# The C++ binaries need UCX from amd-libucx on the loader path, but amd-libucx
# is sdist-only and not pre-installed in the tester (the Python suite compiles
# it later via the amd_libhipucxx wheel). Install it here (--no-binary builds
# ROCm UCX; ROCM_UCX_VERSION picks the release) using the same --find-links as
# test-wheels.sh so the sdist builds once and the later install reuses the
# cached wheel, then put its lib dir on LD_LIBRARY_PATH.
libucx_find_links=()
if [ -n "${BUILD_ARTIFACTS_DIR:-}" ]; then
    libucx_find_links+=(--find-links "${BUILD_ARTIFACTS_DIR}")
fi
pip install --no-binary amd-libucx "${libucx_find_links[@]}" "amd-libucx==1.18.*"

libucx_lib="$(python -c 'import libucx; print(libucx.get_lib())' 2>/dev/null || true)"
if [ -n "${libucx_lib}" ]; then
    export LD_LIBRARY_PATH="${libucx_lib}:${LD_LIBRARY_PATH:-}"
else
    echo "WARNING: could not resolve amd-libucx lib dir (import libucx failed); C++ binaries may fail to find libucp.so.*" >&2
fi

src_dir="${SRC_DIR:-/src}/${PROJECT_ID}"
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
