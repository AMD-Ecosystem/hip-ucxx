#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Build OpenUCX with ROCm support and package it as an RPM.
#
# The RPM is no longer installed here, and the C++ / wheel builds that follow
# source UCX from the amd-libucx package (compiled from the amd-ucx-sdist sdist)
# instead. The RPM is still built and published as an artifact because a
# downstream project still consumes ucx-*.rpm; keep producing it until that
# dependency is removed, after which this script can drop the RPM packaging too.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR
#   ROCM_PATH (or ROCM_HOME)
#   ROCM_UCX_VERSION   -- OpenUCX release to build. The only name for it, so
#                         that the version has one spelling from the CI env
#                         file (_envs/rocmds/<branch> in aisw-ci-builder-tester)
#                         down to here. Not to be confused with UCXX_VERSION,
#                         which is hipUCXX's own version.
#
# Optional environment variables:
#   MAX_JOBS

set -euxo pipefail

: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"

rocm_home="${ROCM_HOME:-${ROCM_PATH:-}}"
: "${rocm_home:?ROCM_PATH or ROCM_HOME must be set}"

ucx_version="${ROCM_UCX_VERSION:?ROCM_UCX_VERSION must be set}"

mkdir -p "${BUILD_ARTIFACTS_DIR}"

ucx_work=$(mktemp -d)
pushd "${ucx_work}"

wget -q "https://github.com/openucx/ucx/releases/download/v${ucx_version}/ucx-${ucx_version}.tar.gz"
tar xzf "ucx-${ucx_version}.tar.gz"
mkdir -p "ucx-${ucx_version}/build"
pushd "ucx-${ucx_version}/build"
../contrib/configure-release \
    --prefix=/usr \
    --with-rocm="${rocm_home}" \
    --with-rc --with-ud --with-dm --with-rdmacm --with-verbs \
    --enable-mt --without-go --disable-assertions
make -j"${MAX_JOBS:-$(nproc)}"

make install DESTDIR=/tmp/ucx-staging
popd
popd
rm -rf "${ucx_work}"

find /tmp/ucx-staging -type f -o -type l | sed 's|/tmp/ucx-staging||' > /tmp/ucx-files.txt

cat > /tmp/ucx.spec << EOF
Name:    ucx
Version: ${ucx_version}
Release: 1%{?dist}
Summary: OpenUCX with ROCm support
License: BSD-3-Clause
AutoReqProv: no

%description
OpenUCX communication framework built with ROCm support.

%install
cp -a /tmp/ucx-staging/* %{buildroot}/

%files -f /tmp/ucx-files.txt
EOF

mkdir -p /tmp/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
rpmbuild -bb /tmp/ucx.spec \
    --define "_topdir /tmp/rpmbuild" \
    --buildroot /tmp/ucx-buildroot

cp /tmp/rpmbuild/RPMS/x86_64/ucx-*.rpm "${BUILD_ARTIFACTS_DIR}"
