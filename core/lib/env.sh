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

# XDG base directories (Linux/WSL defaults)
DOTFILES_XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DOTFILES_XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DOTFILES_XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export DOTFILES_XDG_CONFIG_HOME
export DOTFILES_XDG_STATE_HOME
export DOTFILES_XDG_DATA_HOME

# Dotfiles XDG namespaces
DOTFILES_CONFIG_HOME="${DOTFILES_XDG_CONFIG_HOME}/dotfiles"
DOTFILES_STATE_HOME="${DOTFILES_XDG_STATE_HOME}/dotfiles"
DOTFILES_DATA_HOME="${DOTFILES_XDG_DATA_HOME}/dotfiles"
export DOTFILES_CONFIG_HOME
export DOTFILES_STATE_HOME
export DOTFILES_DATA_HOME

# dotfiles_state_file_path
# Return authoritative state file path.
dotfiles_state_file_path() {
    echo "${DOTFILES_STATE_HOME}/state.json"
}

# Features directory
DOTFILES_FEATURES_DIR="${DOTFILES_ROOT}/features"
export DOTFILES_FEATURES_DIR

# Maximum supported spec_version in feature.yaml.
# Features with a higher spec_version are classified as blocked.
SUPPORTED_FEATURE_SPEC_VERSION=1
export SUPPORTED_FEATURE_SPEC_VERSION

# Profiles directory (override allowed)
if [[ -z "${DOTFILES_PROFILES_DIR:-}" ]]; then
    DOTFILES_PROFILES_DIR="${DOTFILES_CONFIG_HOME}/profiles"
fi
export DOTFILES_PROFILES_DIR

# Source registry file (override allowed)
if [[ -z "${DOTFILES_SOURCES_FILE:-}" ]]; then
    DOTFILES_SOURCES_FILE="${DOTFILES_CONFIG_HOME}/sources.yaml"
fi
export DOTFILES_SOURCES_FILE

# Backend plugins directory
DOTFILES_BACKENDS_DIR="${DOTFILES_ROOT}/backends"
export DOTFILES_BACKENDS_DIR

# Policies directory (for default policy resolution)
DOTFILES_POLICIES_DIR="${DOTFILES_CONFIG_HOME}/policies"
export DOTFILES_POLICIES_DIR

# Policy file: prefer platform-specific, fall back to generic default.
# Can be overridden by setting DOTFILES_POLICY_FILE before sourcing env.sh.
if [[ -z "${DOTFILES_POLICY_FILE:-}" ]]; then
    _policy_candidate="${DOTFILES_POLICIES_DIR}/default.${DOTFILES_PLATFORM}.yaml"
    if [[ -f "$_policy_candidate" ]]; then
        DOTFILES_POLICY_FILE="$_policy_candidate"
    else
        DOTFILES_POLICY_FILE="${DOTFILES_POLICIES_DIR}/default.yaml"
    fi
    export DOTFILES_POLICY_FILE
    unset _policy_candidate
fi
