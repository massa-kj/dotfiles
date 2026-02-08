#!/usr/bin/env bash
# Environment variable definitions

# Root directory of dotfiles
# Assumes this script is located at core/env.sh
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_ROOT

# Platform detection
if [[ -n "${WSL_DISTRO_NAME}" ]]; then
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
