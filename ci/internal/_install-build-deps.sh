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
    # Every wheel pass configures libucxx, whose CPM lookups for rmm and
    # rapids_logger must resolve via find_package() against these wheels. Miss
    # one and CPM builds it from source and installs it into our wheel.
    specs=(
      amd-rocmds-logger
      amd-libhipmm
    )

    # amd_hipucxx Cython (ucxx/_lib) cimports rmm.pylibrmm, whose .pxd chain
    # pulls in cuda.bindings.cyruntime from the hip-python wheel set. libhipucxx
    # and distributed-hipucxx are pure CMake/setuptools and do not need them.
    ucxx_build=${HIPUCXX_BUILD_UCXX-1}
    if [[ -n "${ucxx_build}" ]]; then
      specs+=(
        rocm-bindings-core
        rocm-bindings-hip
        hip-python-interop
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
