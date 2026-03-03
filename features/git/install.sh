#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/fs.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="git"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized (needed for state_add_file below)
state_init

# git package installation is handled by executor (declared in meta.yaml packages).
if ! has_command "git"; then
    log_warn "git not found; executor should have installed it via meta.yaml packages"
fi

# Deploy configuration files
# Note: ~/.config/git/ignore is deployed by executor (declared in meta.yaml files).
# .gitconfig requires a platform-specific merge and is handled here.
FEATURE_FILES_DIR="$SCRIPT_DIR/files"
TARGET_HOME="${HOME}"

CONFIG_TYPE="${DOTFILES_PLATFORM:-linux}"
GITCONFIG_BASE="$FEATURE_FILES_DIR/gitconfig"
GITCONFIG_ENV="$FEATURE_FILES_DIR/.gitconfig.$CONFIG_TYPE"
GITCONFIG_TARGET="$TARGET_HOME/.gitconfig"
GITCONFIG_TEMP="/tmp/.gitconfig.$$"

if [[ -f "$GITCONFIG_BASE" ]]; then
    if [[ -f "$GITCONFIG_ENV" ]]; then
        log_info "Merging gitconfig with $CONFIG_TYPE settings..."
        cat "$GITCONFIG_BASE" "$GITCONFIG_ENV" > "$GITCONFIG_TEMP"
    else
        log_warn "Platform-specific config not found: $GITCONFIG_ENV"
        cp "$GITCONFIG_BASE" "$GITCONFIG_TEMP"
    fi

    if [[ -f "$GITCONFIG_TARGET" ]]; then
        if ! diff -q "$GITCONFIG_TEMP" "$GITCONFIG_TARGET" > /dev/null 2>&1; then
            log_warn ".gitconfig differs from expected. Creating backup..."
            backup_file "$GITCONFIG_TARGET"
            cp "$GITCONFIG_TEMP" "$GITCONFIG_TARGET"
            log_success ".gitconfig updated"
        else
            log_info ".gitconfig is up-to-date"
        fi
    else
        cp "$GITCONFIG_TEMP" "$GITCONFIG_TARGET"
        log_success ".gitconfig created"
    fi

    # Register generated .gitconfig in state (dynamically merged; not in meta.yaml files)
    state_add_file "$FEATURE_NAME" "$GITCONFIG_TARGET"

    rm -f "$GITCONFIG_TEMP"
fi

# Note: ~/.config/git/ignore is deployed by executor (declared in meta.yaml files).

log_success "Feature $FEATURE_NAME installed successfully"
