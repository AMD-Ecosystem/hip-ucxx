# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Install test dependencies for hipUCXX wheel tests.
# Meant to be sourced, not executed directly.

set -euo pipefail

install_hipucxx_test_deps() {
    pip install pytest pytest-timeout pytest-asyncio "pytest-rerunfailures!=16.0.0"
}
