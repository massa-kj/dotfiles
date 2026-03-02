#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: env
#
# Responsibility:
#   Define environment variables for dotfiles framework.
# -----------------------------------------------------------------------------

# Root directory of dotfiles
# Assumes this script is located at core/lib/env.sh
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTFILES_ROOT

# Platform detection
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    DOTFILES_PLATFORM="wsl"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DOTFILES_PLATFORM="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    DOTFILES_PLATFORM="windows"
else
    DOTFILES_PLATFORM="unknown"
fi
export DOTFILES_PLATFORM

# Path to state file
DOTFILES_STATE_FILE="${DOTFILES_ROOT}/state/installed.json"
export DOTFILES_STATE_FILE

# State directory
DOTFILES_STATE_DIR="${DOTFILES_ROOT}/state"
export DOTFILES_STATE_DIR

# Features directory
DOTFILES_FEATURES_DIR="${DOTFILES_ROOT}/features"
export DOTFILES_FEATURES_DIR

# Profiles directory
DOTFILES_PROFILES_DIR="${DOTFILES_ROOT}/profiles"
export DOTFILES_PROFILES_DIR

# Backend plugins directory
DOTFILES_BACKENDS_DIR="${DOTFILES_ROOT}/backends"
export DOTFILES_BACKENDS_DIR

# Policy file: prefer platform-specific, fall back to generic default.
# Can be overridden by setting DOTFILES_POLICY_FILE before sourcing env.sh.
if [[ -z "${DOTFILES_POLICY_FILE:-}" ]]; then
    _policy_candidate="${DOTFILES_ROOT}/policies/default.${DOTFILES_PLATFORM}.yaml"
    if [[ -f "$_policy_candidate" ]]; then
        DOTFILES_POLICY_FILE="$_policy_candidate"
    else
        DOTFILES_POLICY_FILE="${DOTFILES_ROOT}/policies/default.yaml"
    fi
    export DOTFILES_POLICY_FILE
    unset _policy_candidate
fi
