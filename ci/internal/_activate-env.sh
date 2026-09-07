# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Shared helper: conda/venv activation for hipUCXX CI.
# Meant to be sourced, not executed directly.
#
# Provides:
#   activate_hipucxx_dev_env()  - activates conda or the dev venv
#   hipucxx_has_target()        - checks HIPUCXX_TARGETS for a token

set -euo pipefail

activate_hipucxx_dev_env() {
    if [ -n "${HIPUCXX_CONDA_ENV:-}" ]; then
        set +u
        # shellcheck source=/dev/null
        . "${CONDA_DIR}/etc/profile.d/conda.sh"
        conda activate "${HIPUCXX_CONDA_ENV}"
        set -u
        export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
        return 0
    fi

    if [ -f "${INSTALL_DIR}/venv/hipucxx_dev/bin/activate" ]; then
        # shellcheck source=/dev/null
        . "${INSTALL_DIR}/venv/hipucxx_dev/bin/activate"
        return 0
    fi

    return 1
}

activate_hipucxx_python_environment() {
    if ! activate_hipucxx_dev_env; then
        python3 -m venv --clear "${INSTALL_DIR}/venv/hipucxx_dev"
        # shellcheck source=/dev/null
        . "${INSTALL_DIR}/venv/hipucxx_dev/bin/activate"
        pip install --upgrade pip
    fi
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
