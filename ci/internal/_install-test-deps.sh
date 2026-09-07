# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Install test dependencies for hipUCXX wheel tests.
# Meant to be sourced, not executed directly.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- directory containing pre-built dependency wheels

set -euo pipefail

pip install --upgrade pip
pip install cloudpickle pytest pytest-timeout pytest-asyncio "pytest-rerunfailures!=16.0.0"

# hipUCXX wheels are installed separately by test-wheels.sh.
pip install --no-deps \
    --find-links "${BUILD_ARTIFACTS_DIR}" \
    amd-rocmds-logger \
    amd-cupy \
    rocm-bindings-core \
    rocm-bindings-hip \
    hip-python-interop \
    numba-hip \
    amd-libhipmm \
    amd-hipmm
