#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Run the hipUCXX Python suite once per supported interpreter, against the wheel
# pool build-wheels-manylinux.sh produced.
#
# The pool holds two amd_hipucxx tag families, cp311-cp311 and cp312-abi3, and
# each interpreter is served by exactly one of them. Nothing here decides which:
# test-wheels.sh asks pip for the distributions by name and pip matches the
# tags, so 3.13 lands on the abi3 wheel for free. That is the point of the abi3
# entry, and the reason 3.13 is tested here without being built for.
#
# The C++ suite is not driven from here. It is interpreter-independent, so
# test-cpp.sh runs once, beside this script rather than inside it.
#
# Required environment variables:
#   PROJECT_ID, BUILD_DIR, BUILD_ARTIFACTS_DIR, ARTIFACTS_DIR
#
# Optional environment variables:
#   HIPUCXX_TEST_PYTHONS -- whitespace-separated CPython versions to test
#                           (default: "3.11 3.12 3.13")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR must be set}"

export PROJECT_ID BUILD_DIR BUILD_ARTIFACTS_DIR ARTIFACTS_DIR

test_pythons=${HIPUCXX_TEST_PYTHONS:-"3.11 3.12 3.13"}

base_path=${PATH}

tested_versions=()
statuses=()

for python_version in ${test_pythons}; do
  tag="cp${python_version//./}"
  python_bin="/opt/python/${tag}-${tag}/bin"

  echo "=============================================================="
  echo "hipUCXX Python tests on CPython ${python_version}"
  echo "=============================================================="

  tested_versions+=("${python_version}")

  if [ ! -x "${python_bin}/python" ]; then
    echo "ERROR: no CPython ${python_version} in this image;" \
         "${python_bin}/python is missing." >&2
    statuses+=("MISSING")
    continue
  fi

  if PATH="${python_bin}:${base_path}" "${SCRIPT_DIR}/test-wheels.sh"; then
    statuses+=("PASS")
  else
    statuses+=("FAIL")
  fi
done

if [ ${#tested_versions[@]} -eq 0 ]; then
  echo "ERROR: HIPUCXX_TEST_PYTHONS is empty; nothing was tested." >&2
  exit 1
fi

echo "=============================================================="
echo "Summary"
echo "=============================================================="

failed=0
for i in "${!tested_versions[@]}"; do
  printf '  CPython %-5s %s\n' "${tested_versions[${i}]}" "${statuses[${i}]}"
  if [ "${statuses[${i}]}" != "PASS" ]; then
    failed=$((failed + 1))
  fi
done

if [ ${failed} -gt 0 ]; then
  echo "${failed} of ${#tested_versions[@]} interpreters did not pass." >&2
  exit 1
fi

echo "All ${#tested_versions[@]} interpreters passed."
