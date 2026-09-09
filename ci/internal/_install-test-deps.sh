# shellcheck shell=bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Install test dependencies for hipUCXX wheel tests.
# Meant to be sourced, not executed directly.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- directory containing pre-built dependency wheels
#
# Optional environment variables:
#   ROCMDS_LOGGER_VERSION -- pins amd-rocmds-logger
#   HIPMM_VERSION         -- pins amd-libhipmm and amd-hipmm
#   NUMBA_HIP_VERSION     -- pins numba-hip
#                            CI sets these from the builder-tester
#                            _envs/rocmds/<branch> env file, and a bare checkout
#                            without them installs unpinned

set -euo pipefail

pip install --upgrade pip
pip install cloudpickle pytest pytest-timeout pytest-asyncio "pytest-rerunfailures!=16.0.0"

# Wheel/runtime deps staged from upstream ci_packages (hip-python, hipmm).
# tmpfix: amd-cupy disabled while debugging the integration build.
# hipUCXX wheels are installed separately by test-wheels.sh.
# rocm-bindings-* and hip-python-interop stay unpinned: their version leads with
# the base image's ROCm version, which no env key names.
pip install --no-deps \
    --find-links "${BUILD_ARTIFACTS_DIR}" \
    "amd-rocmds-logger${ROCMDS_LOGGER_VERSION:+==${ROCMDS_LOGGER_VERSION}}" \
    rocm-bindings-core \
    rocm-bindings-hip \
    hip-python-interop \
    "numba-hip${NUMBA_HIP_VERSION:+==${NUMBA_HIP_VERSION}}" \
    "amd-libhipmm${HIPMM_VERSION:+==${HIPMM_VERSION}}" \
    "amd-hipmm${HIPMM_VERSION:+==${HIPMM_VERSION}}"
