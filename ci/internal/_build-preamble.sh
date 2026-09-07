# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build preamble: toolchain and Python build environment for hipUCXX.
# Meant to be sourced, not executed directly.
#
# Required environment variables:
#   CMAKE_VERSION
#
# Optional environment variables:
#   ROCM_PATH

set -euo pipefail

_PREAMBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_activate-env.sh
source "${_PREAMBLE_DIR}/_activate-env.sh"

setup_build_environment() {
    pip install "cmake==${CMAKE_VERSION}" ninja

    export ROCM_PATH="${ROCM_PATH:-/opt/rocm}"
    export ROCM_HOME="${ROCM_PATH}"

    export CPM_USE_LOCAL_PACKAGES=True
    export CC=hipcc
    export CXX=hipcc
}
