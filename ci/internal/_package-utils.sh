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

_install_artifact_package() {
    local name=$1
    local pkg_fmt ext processed pattern
    pkg_fmt=$(package_format) || return 1
    [[ "${pkg_fmt}" == "RPM" ]] && ext="rpm" || ext="deb"

    # make each - or _ match either separator: rocmds-logger -> rocmds[-_]logger
    processed="${name//[-_]/[-_]}"
    pattern="${BUILD_ARTIFACTS_DIR}/*${processed}*.${ext}"

    local -a matches=()
    _collect_matching_files matches "${pattern}"
    if ((${#matches[@]} == 0)); then
        echo "ERROR: no ${name} ${ext} package found in ${BUILD_ARTIFACTS_DIR}" >&2
        return 1
    fi

    if [[ "${pkg_fmt}" == "RPM" ]]; then
        rpm -ivh --force --nodeps "${matches[@]}"
    else
        apt install -y "${matches[@]}"
    fi
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

# The dev pipelines pool the upstream packages this component builds against
# into BUILD_ARTIFACTS_DIR, and the two installers below consume them from
# there. An image that already carries those dependencies, as the manylinux CI
# builder does through its yum and pip layers, stages nothing and sets this to
# 0; the globs would otherwise find no match and fail the build.
install_deps_from_artifacts() {
    [[ "${CI_INTERNAL_INSTALL_DEPS_FROM_ARTIFACTS:-1}" != "0" ]]
}

install_cpp_packages_from_artifacts() {
    if install_deps_from_artifacts; then
        _install_artifact_package rocmds-logger
        _install_artifact_package rocmds-cmake
        _install_artifact_package libhipcxx
        _install_artifact_package hipmm
    else
        echo "CI_INTERNAL_INSTALL_DEPS_FROM_ARTIFACTS=0: taking the C++ dependencies as already installed."
    fi

    # Where the packages above land, and also where an image that pre-installs
    # them puts them, so this part holds either way.
    local rocmds_home="/opt/rocm-ds"
    export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-}:${rocmds_home}"
    # Caller wins: the manylinux builder points this at the rapids-cmake
    # checkout in its sources, which no package installs.
    export RAPIDS_CMAKE_MODULE_PATH="${RAPIDS_CMAKE_MODULE_PATH:-${rocmds_home}/share/cmake/rocmds-cmake/modules}"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:${rocmds_home}/lib64:${rocmds_home}/lib"
}

install_python_wheels_from_artifacts() {
    if ! install_deps_from_artifacts; then
        echo "CI_INTERNAL_INSTALL_DEPS_FROM_ARTIFACTS=0: taking the Python dependencies as already installed."
        return 0
    fi

    pip install --find-links "${BUILD_ARTIFACTS_DIR}" \
        "${BUILD_ARTIFACTS_DIR}"/hip_python*.whl \
        "${BUILD_ARTIFACTS_DIR}"/*rocmds_logger*.whl \
        "${BUILD_ARTIFACTS_DIR}"/amd_libhipmm*.whl \
        "${BUILD_ARTIFACTS_DIR}"/amd_hipmm*.whl \
        "${BUILD_ARTIFACTS_DIR}"/numba_hip*.whl
}
