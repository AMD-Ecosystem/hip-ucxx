# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Wheel helpers for hipUCXX CI.
# Meant to be sourced, not executed directly.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR

set -euo pipefail

# Retag rather than repair: the wheels are meant to keep loading the libraries
# they were built against, so nothing is vendored in, only the platform tag is
# corrected from the generic linux_x86_64 that setuptools writes.
retag_linux_wheels() {
    pip install auditwheel

    shopt -s nullglob
    for wheel in "${BUILD_ARTIFACTS_DIR}"/*-linux_x86_64.whl; do
        platform_tag=$(python -m auditwheel show "${wheel}" \
            | grep -o 'platform tag to ".\+"' | cut -d '"' -f 2)
        if [ -z "${platform_tag}" ]; then
            echo "ERROR: auditwheel reported no platform tag for ${wheel}" >&2
            exit 1
        fi
        mv -v "${wheel}" "${wheel/linux_x86_64/${platform_tag}}"
    done
    shopt -u nullglob
}
