#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# NOTE: meant to be sourced

package_format() {
    local os_id_like
    os_id_like=$(. /etc/os-release; echo "$ID_LIKE")
    if [[ "${os_id_like}" == *"debian"* ]]; then
        echo DEB
    elif [[ "${os_id_like}" == *"rhel"* ]]; then
        echo RPM
    else
        echo "ERROR: OS not handled for package install (id_like=${os_id_like})" >&2
        return 1
    fi
}

_collect_matching_files() {
    local -n _out=$1
    shift
    local pattern
    shopt -s nullglob
    _out=()
    for pattern in "$@"; do
        _out+=("${pattern}")
    done
    shopt -u nullglob
}

_install_rpm_globs() {
    local label=$1
    shift
    local -a matches=()
    _collect_matching_files matches "$@"
    if ((${#matches[@]} == 0)); then
        echo "ERROR: no ${label} RPM found in ${BUILD_ARTIFACTS_DIR}" >&2
        return 1
    fi
    #dnf install -y "${matches[@]}"
    rpm -ivh --force --nodeps "${matches[@]}"
}

_install_deb_globs() {
    local label=$1
    shift
    local -a matches=()
    _collect_matching_files matches "$@"
    if ((${#matches[@]} == 0)); then
        echo "ERROR: no ${label} DEB found in ${BUILD_ARTIFACTS_DIR}" >&2
        return 1
    fi
    apt install -y "${matches[@]}"
}

activate_python_environment() {
    if [ -n "${HIPUCXX_CONDA_ENV:-}" ]; then
        set +u # note: conda script may have unbound variables
        . "${CONDA_DIR}/etc/profile.d/conda.sh"
        conda activate "${HIPUCXX_CONDA_ENV}"
        set -u
    else
        python3 -m venv --clear "${INSTALL_DIR}/venv/hipucxx"
        # shellcheck source=/dev/null
        . "${INSTALL_DIR}/venv/hipucxx/bin/activate"
    fi
    pip install --upgrade pip
}

setup_build_environment() {
    pip install "cmake==${CMAKE_VERSION}" ninja

    export ROCM_PATH="/opt/rocm"
    export ROCM_HOME="/opt/rocm"

    export CPM_USE_LOCAL_PACKAGES=True
    export CC=hipcc
    export CXX=hipcc
}

hipucxx_has_target() {
    local needle="$1"
    local token
    IFS=',' read -ra _targets <<< "${HIPUCXX_TARGETS:-}"
    for token in "${_targets[@]}"; do
        token="${token#"${token%%[![:space:]]*}"}"
        token="${token%"${token##*[![:space:]]}"}"
        [[ "${token}" == "${needle}" ]] && return 0
    done
    return 1
}

install_cpp_packages_from_artifacts() {
    local pkg_fmt
    pkg_fmt=$(package_format)

    if [[ "${pkg_fmt}" == "RPM" ]]; then
        _install_rpm_globs rocmds_logger "${BUILD_ARTIFACTS_DIR}"/*rocmds*logger*.rpm
        _install_rpm_globs rocmds-cmake "${BUILD_ARTIFACTS_DIR}"/*rocmds*cmake*.rpm
        _install_rpm_globs libhipcxx "${BUILD_ARTIFACTS_DIR}"/*libhipcxx*.rpm
        _install_rpm_globs hipmm "${BUILD_ARTIFACTS_DIR}"/*hipmm*.rpm
    else
        _install_deb_globs rocmds_logger "${BUILD_ARTIFACTS_DIR}"/*rocmds*logger*.deb
        _install_deb_globs rocmds-cmake "${BUILD_ARTIFACTS_DIR}"/*rocmds*cmake*.deb
        _install_deb_globs libhipcxx "${BUILD_ARTIFACTS_DIR}"/*libhipcxx*.deb
        _install_deb_globs hipmm "${BUILD_ARTIFACTS_DIR}"/*hipmm*.deb
    fi

    local rocmds_home="/opt/rocm-ds"
    export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}:${rocmds_home}"
    export RAPIDS_CMAKE_MODULE_PATH="${rocmds_home}/share/cmake/rocmds-cmake/modules"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:${rocmds_home}/lib64:${rocmds_home}/lib"
}

install_python_wheels_from_artifacts() {
    pip install --find-links "${BUILD_ARTIFACTS_DIR}" \
        "${BUILD_ARTIFACTS_DIR}"/hip_python*.whl \
        "${BUILD_ARTIFACTS_DIR}"/*rocmds_logger*.whl \
        "${BUILD_ARTIFACTS_DIR}"/amd_libhipmm*.whl \
        "${BUILD_ARTIFACTS_DIR}"/amd_hipmm*.whl \
        "${BUILD_ARTIFACTS_DIR}"/numba_hip*.whl
}
