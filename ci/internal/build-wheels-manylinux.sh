#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build the hipUCXX wheel matrix inside a manylinux container.
#
# One build-wheels.sh pass per wheel and matrix entry, all of them writing into
# the same BUILD_ARTIFACTS_DIR, so the stage ends with a single wheel pool that
# covers the whole supported interpreter range:
#
#   amd_libhipucxx          ... py3-none, built once
#   amd_distributed_hipucxx ... py3-none-any, built once
#   amd_hipucxx             ... one per entry, because ucxx/_lib and
#                               ucxx/examples are Cython:
#
#     3.11, no SABI    -> cp311-cp311
#     3.12, SABI 3.12  -> cp312-abi3
#
# Run this after build-dev.sh, never before: build-wheels.sh sources
# _build-preamble.sh, which recreates ${INSTALL_DIR}/venv/hipucxx_dev with
# --clear, and that venv is what build-dev.sh packs into the tests tarball.
#
# Required environment variables:
#   PROJECT_ID, SRC_DIR, BUILD_DIR, INSTALL_DIR, BUILD_ARTIFACTS_DIR
#   Everything else build-wheels.sh reads (AMDGPU_TARGETS, ROCM_PATH,
#   CMAKE_VERSION, CMAKE_INSTALL_PREFIX, ...) is passed through untouched.
#   BUILD_DIR, USE_SABI, HIPUCXX_BUILD_TYPE and the HIPUCXX_BUILD_* switches
#   are the exceptions: this script sets them per pass.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"

export PROJECT_ID SRC_DIR INSTALL_DIR BUILD_ARTIFACTS_DIR

mkdir -p "${BUILD_ARTIFACTS_DIR}"

python_versions=(3.11 3.12)
sabi_floors=(no 3.12)
expected_tags=(cp311-cp311 cp312-abi3)

python_bins=(
    /opt/python/cp311-cp311/bin
    /opt/python/cp312-cp312/bin
)

for python_bin in "${python_bins[@]}"; do
    if [ ! -x "${python_bin}/python" ]; then
        echo "ERROR: ${python_bin}/python is missing." >&2
        exit 1
    fi
done

base_path=${PATH}
HIPUCXX_BUILD_TYPE=wheels

echo "=============================================================="
echo "amd_libhipucxx and amd_distributed_hipucxx, built once with CPython ${python_versions[0]}"
echo "=============================================================="

PATH="${python_bins[0]}:${base_path}" \
BUILD_DIR="${BUILD_DIR}/libhipucxx" \
HIPUCXX_BUILD_TYPE="${HIPUCXX_BUILD_TYPE}" \
HIPUCXX_BUILD_UCXX= \
HIPUCXX_BUILD_LIBHIPUCXX=1 \
HIPUCXX_BUILD_DISTRIBUTED=1 \
    "${SCRIPT_DIR}/build-wheels.sh"

for i in "${!python_versions[@]}"; do
    python_version=${python_versions[${i}]}
    sabi=${sabi_floors[${i}]}
    python_bin=${python_bins[${i}]}

    echo "=============================================================="
    echo "amd_hipucxx for CPython ${python_version} (USE_SABI=${sabi})"
    echo "=============================================================="

    PATH="${python_bin}:${base_path}" \
    BUILD_DIR="${BUILD_DIR}/cp${python_version//./}" \
    HIPUCXX_BUILD_TYPE="${HIPUCXX_BUILD_TYPE}" \
    HIPUCXX_BUILD_UCXX=1 \
    HIPUCXX_BUILD_LIBHIPUCXX= \
    HIPUCXX_BUILD_DISTRIBUTED= \
    USE_SABI="${sabi}" \
        "${SCRIPT_DIR}/build-wheels.sh"
done

shopt -s nullglob

missing=()

echo "=============================================================="
echo "Wheels in ${BUILD_ARTIFACTS_DIR}"
echo "=============================================================="

for dist in amd_libhipucxx amd_distributed_hipucxx; do
    found=("${BUILD_ARTIFACTS_DIR}/${dist}"-*-py3-none-*.whl)
    printf '  %-24s %-14s %d wheel(s)\n' "${dist}" "py3-none" "${#found[@]}"
    if [ ${#found[@]} -eq 0 ]; then
        missing+=("${dist} (py3-none)")
    fi
done

for i in "${!expected_tags[@]}"; do
    expected_tag=${expected_tags[${i}]}

    found=("${BUILD_ARTIFACTS_DIR}"/amd_hipucxx-*-"${expected_tag}"-*.whl)
    printf '  %-24s %-14s %d wheel(s)\n' "amd_hipucxx" "${expected_tag}" "${#found[@]}"
    if [ ${#found[@]} -eq 0 ]; then
        missing+=("amd_hipucxx from CPython ${python_versions[${i}]} (${expected_tag})")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: the wheel matrix is incomplete. Nothing produced:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    echo "Wheels that are present:" >&2
    ls -1 "${BUILD_ARTIFACTS_DIR}" >&2 || true
    exit 1
fi

unexpected=()
for bad_tag in cp312-cp312 cp313-cp313; do
    found=("${BUILD_ARTIFACTS_DIR}"/amd_hipucxx-*-"${bad_tag}"-*.whl)
    if [ ${#found[@]} -gt 0 ]; then
        unexpected+=("${bad_tag} (${#found[@]} wheel(s))")
    fi
done
if [ ${#unexpected[@]} -gt 0 ]; then
    echo "ERROR: version-specific wheels outside the matrix:" >&2
    printf '  - %s\n' "${unexpected[@]}" >&2
    ls -1 "${BUILD_ARTIFACTS_DIR}"/amd_hipucxx*.whl >&2 || true
    exit 1
fi

echo "Wheel matrix complete."
