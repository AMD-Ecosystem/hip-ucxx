#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Install OS-level prerequisites for hipUCXX builds.
#
# UCX itself is built by build-ucx.sh, which runs after this script.

set -xeu

os_id=$(. /etc/os-release; echo "$ID")
os_id_like=$(. /etc/os-release; echo "$ID_LIKE")

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
