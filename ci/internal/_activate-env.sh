# SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
# SPDX-License-Identifier: MIT

# Shared helper: conda/venv activation for hipUCXX CI.
# Meant to be sourced, not executed directly.
#
# Provides:
#   activate_hipucxx_python_environment() - activates conda or creates dev venv
#   hipucxx_has_target()                  - checks HIPUCXX_TARGETS for a token

set -euo pipefail

activate_hipucxx_python_environment() {
    if [ -n "${HIPUCXX_CONDA_ENV:-}" ]; then
        set +u # note: conda script may have unbound variables
        # shellcheck source=/dev/null
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
