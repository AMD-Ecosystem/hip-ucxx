# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Install build dependencies for hipUCXX.
# Meant to be sourced, not executed directly.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- directory containing pre-built dependency wheels
#   HIPUCXX_BUILD_TYPE  -- controls which dependencies to install
#   CMAKE_VERSION       -- the version of the cmake package to install

set -euo pipefail

pip install --upgrade pip

case "${HIPUCXX_BUILD_TYPE:-}" in
  wheels)
    specs=(
      amd-rocmds-logger
    )

    # ucxx/_lib cimports cuda.bindings.cyruntime and rmm.pylibrmm.
    need_hip_python_deps=0
    [[ -n "${HIPUCXX_BUILD_UCXX-1}" ]] && need_hip_python_deps=1
    [[ -n "${HIPUCXX_BUILD_DISTRIBUTED-1}" ]] && need_hip_python_deps=1

    if [ "${need_hip_python_deps}" -eq 1 ]; then
      specs+=(
        rocm-bindings-core
        rocm-bindings-hip
        hip-python-interop
        amd-libhipmm
        amd-hipmm
      )
    fi

    pip install --no-deps \
        --find-links "${BUILD_ARTIFACTS_DIR}" \
        "${specs[@]}"
    ;;
esac

pip install wheel auditwheel Cython scikit-build-core setuptools packaging
pip install --force-reinstall "cmake==${CMAKE_VERSION}"
pip install ninja
