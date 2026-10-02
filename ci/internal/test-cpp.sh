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

# hipUCXX sources UCX from the amd-libucx package (site-packages/libucx/lib64),
# not a system path. The Python tests load it via libucx.load_library(), but the
# standalone C++ test/example/benchmark binaries rely on the dynamic loader, so
# make libucp.so.0 and friends discoverable. Works for both the conda and venv
# activation paths since it uses the active interpreter's installed package.
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
