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
#     3.11 -> cp311-cp311
#     3.12 -> cp312-cp312
#     3.13 -> cp313-cp313
#
# One entry per interpreter rather than a single stable-ABI wheel: ucxx/_lib
# cannot be compiled with Py_LIMITED_API, because arr.pyx cimports
# PyMemoryView_GET_BUFFER and PyTuple_SET_ITEM. Both live under cpython/ in
# every CPython from 3.12 to 3.15, that is, outside the limited API, so no SABI
# floor makes that pass -- arr.pyx has to move to PyObject_GetBuffer and
# PyTuple_SetItem first. Every interpreter the tests cover therefore needs its
# own entry here; nothing is inherited from a lower one.
#
# Independent of the dev venv: build-wheels.sh activates nothing, so it can
# neither clobber the ${INSTALL_DIR}/venv/hipucxx_dev that build-dev.sh packs
# into the tests tarball, nor let that venv's interpreter shadow the per-pass
# one set on PATH below.
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

python_versions=(3.11 3.12 3.13)
# Kept as a per-entry array, so flipping one interpreter back to the stable ABI
# once arr.pyx allows it is a one-token change here.
sabi_floors=(no no no)
expected_tags=(cp311-cp311 cp312-cp312 cp313-cp313)

python_bins=(
    /opt/python/cp311-cp311/bin
    /opt/python/cp312-cp312/bin
    /opt/python/cp313-cp313/bin
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
HIPUCXX_BUILD_UCXX='' \
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
    HIPUCXX_BUILD_LIBHIPUCXX='' \
    HIPUCXX_BUILD_DISTRIBUTED='' \
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

# An abi3 wheel here means USE_SABI came back for a pass while arr.pyx still
# cimports the two macros the limited API excludes. That build cannot have
# compiled ucxx/_lib, so whatever produced the wheel is not what the tag claims.
abi3_wheels=("${BUILD_ARTIFACTS_DIR}"/amd_hipucxx-*-abi3-*.whl)
if [ ${#abi3_wheels[@]} -gt 0 ]; then
    echo "ERROR: stable-ABI wheels in a matrix built without SABI:" >&2
    printf '  - %s\n' "${abi3_wheels[@]##*/}" >&2
    ls -1 "${BUILD_ARTIFACTS_DIR}"/amd_hipucxx*.whl >&2 || true
    exit 1
fi

echo "Wheel matrix complete."
