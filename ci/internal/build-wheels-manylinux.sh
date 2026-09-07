#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build the hipUCXX wheel matrix inside a manylinux container.
#
# One build-wheels.sh pass per matrix entry, all writing into the same
# BUILD_ARTIFACTS_DIR, so the stage ends with a single wheel pool that covers
# the whole supported interpreter range:
#
#   amd_hipucxx             ... one per entry, because ucxx/_lib and
#                               ucxx/examples are Cython:
#
#     3.11, no SABI    -> cp311-cp311
#     3.12, SABI 3.12  -> cp312-abi3, which installs on 3.12 and on every later
#                         CPython, so the tail of the range needs no build of
#                         its own
#
#   amd_libhipucxx          ... py3-none, python/libucxx pins wheel.py-api
#   amd_distributed_hipucxx ... py3-none-any, pure Python
#
# The last two carry no interpreter tag, so every pass rebuilds an identical
# wheel and the later pass simply overwrites the earlier one. Skipping them in
# the second pass would save a libucxx compile, but only by giving up
# build.hip.sh's own target resolution, which pulls libucxx_py in whenever ucxx
# is built without --find-libucxx.
#
# Manylinux-specific by construction: the interpreters come from
# /opt/python/cp<xy>-cp<xy>, which is a manylinux layout. Another distro wants a
# sibling driver rather than a fallback hidden in here.
#
# Required environment variables:
#   PROJECT_ID, SRC_DIR, BUILD_DIR, INSTALL_DIR, BUILD_ARTIFACTS_DIR
#   Everything else build-wheels.sh reads (AMDGPU_TARGETS, CMAKE_VERSION,
#   HIPUCXX_GPU_ARCHS, ...) is passed through untouched. BUILD_DIR and the
#   HIPUCXX_WHEEL_* switches are the exceptions: this script sets them per pass.

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

python_bins=()
for python_version in "${python_versions[@]}"; do
  tag="cp${python_version//./}"
  python_bins+=("/opt/python/${tag}-${tag}/bin")

  if [ ! -x "/opt/python/${tag}-${tag}/bin/python" ]; then
    echo "ERROR: no CPython ${python_version} in this image;" \
         "/opt/python/${tag}-${tag}/bin/python is missing." >&2
    exit 1
  fi
done

base_path=${PATH}

for i in "${!python_versions[@]}"; do
  python_version=${python_versions[${i}]}
  sabi=${sabi_floors[${i}]}
  python_bin=${python_bins[${i}]}
  tag="cp${python_version//./}"

  if [ "${sabi}" = "no" ]; then
    py_api=
  else
    py_api="cp${sabi//./}"
  fi

  echo "=============================================================="
  echo "amd_hipucxx for CPython ${python_version} (SABI floor: ${sabi})"
  echo "=============================================================="

  PATH="${python_bin}:${base_path}" \
  BUILD_DIR="${BUILD_DIR}/${tag}" \
  HIPUCXX_WHEEL_PY_API="${py_api}" \
  HIPUCXX_WHEEL_PLATFORM_RETAG=1 \
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

echo "Wheel matrix complete."
