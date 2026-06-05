#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

set -xeu

os_id=$(. /etc/os-release; echo "$ID")
os_id_like=$(. /etc/os-release; echo "$ID_LIKE")

rocm_home="${ROCM_HOME:-${ROCM_PATH:-/opt/rocm}}"

if [[ "${os_id}" == *"ubuntu"* ]]; then
    apt-get update
    apt-get install -y \
        libibverbs-dev \
        librdmacm-dev \
        libnuma-dev \
        wget \
        build-essential \
        python3-pip \
        python3-dev \
        python3-venv \
        dpkg-dev \
        fakeroot
elif [[ "${os_id_like}" == *"rhel"* ]]; then
    dnf install -y \
        libibverbs-devel \
        librdmacm-devel \
        numactl-devel \
        wget \
        gcc \
        gcc-c++ \
        make \
        python3-pip \
        python3-devel \
        rpm-build
else
    echo "ERROR: unsupported OS id=${os_id} id_like=${os_id_like}" >&2
    exit 1
fi

ucx_version="${HIPUCXX_UCX_VERSION}"
ucx_tarball="ucx-${ucx_version}.tar.gz"
ucx_url="https://github.com/openucx/ucx/releases/download/v${ucx_version}/${ucx_tarball}"

work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

cd "${work_dir}"
wget -q "${ucx_url}"
tar xzf "${ucx_tarball}"
cd "ucx-${ucx_version}"

env -i PATH="${PATH}" CC=gcc CXX=g++ ./contrib/configure-release \
    --prefix=/usr \
    --with-rocm="${rocm_home}" \
    --with-rc --with-ud --with-dm --with-rdmacm --with-verbs \
    --enable-mt --without-go --disable-assertions

make -j "${MAX_JOBS:-$(nproc)}"
make install
