#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

set -xeu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_build-preamble.sh
. "${SCRIPT_DIR}/_build-preamble.sh"
# shellcheck source=_install-artifact-deps.sh
. "${SCRIPT_DIR}/_install-artifact-deps.sh"

activate_hipucxx_python_environment

setup_build_environment

pkg_fmt=$(package_format)
parallel="${PARALLEL_LEVEL:-${MAX_JOBS:-$(nproc)}}"

hipmm_build="${BUILD_DIR}/hipmm/cpp/build"
if [[ ! -d "${hipmm_build}" ]]; then
    echo "ERROR: hipmm C++ build dir missing (${hipmm_build}); run hipmm-build-dev first" >&2
    exit 1
fi

cmake "${hipmm_build}" -DCMAKE_SKIP_INSTALL_ALL_DEPENDENCY=ON
(
    cd "${hipmm_build}"
    cpack -G "${pkg_fmt}"
)

logger_src="${BUILD_DIR}/rocmds_logger"
if [[ ! -d "${logger_src}" ]]; then
    echo "ERROR: rocmds_logger source dir missing (${logger_src}); run rocmds_logger-build-dev first" >&2
    exit 1
fi
logger_build="${logger_src}/build"

mkdir -p "${logger_build}"
CC=hipcc CXX=hipcc cmake -S "${logger_src}" -B "${logger_build}" -G Ninja "-DCPACK_OUTPUT_FILE_PREFIX=${BUILD_ARTIFACTS_DIR}"
cmake --build "${logger_build}" -j "${parallel}"
(
    cd "${logger_build}"
    cpack -G "${pkg_fmt}"
)
