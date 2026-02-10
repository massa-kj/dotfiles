#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/package.sh"
source "$DOTFILES_ROOT/core/lib/fs.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="git"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Check if git is already installed (bootstrap should have installed it)
if has_command "git"; then
    log_info "git is already installed"
else
    log_info "Installing git package..."
    install_package "git"
    state_add_package "$FEATURE_NAME" "git"
    log_success "git package installed"
fi

# Deploy configuration files
FEATURE_FILES_DIR="$SCRIPT_DIR/files"
TARGET_HOME="${HOME}"

log_info "Deploying configuration files..."

# Determine platform-specific config
CONFIG_TYPE="${DOTFILES_PLATFORM:-linux}"
GITCONFIG_BASE="$FEATURE_FILES_DIR/gitconfig"
GITCONFIG_ENV="$FEATURE_FILES_DIR/.gitconfig.$CONFIG_TYPE"
GITCONFIG_TARGET="$TARGET_HOME/.gitconfig"
GITCONFIG_TEMP="/tmp/.gitconfig.$$"

# Merge base and platform-specific gitconfig
if [[ -f "$GITCONFIG_BASE" ]]; then
    if [[ -f "$GITCONFIG_ENV" ]]; then
        log_info "Merging gitconfig with $CONFIG_TYPE settings..."
        cat "$GITCONFIG_BASE" "$GITCONFIG_ENV" > "$GITCONFIG_TEMP"
    else
        log_warn "Platform-specific config not found: $GITCONFIG_ENV"
        cp "$GITCONFIG_BASE" "$GITCONFIG_TEMP"
    fi
    
    # Check if target exists and differs
    if [[ -f "$GITCONFIG_TARGET" ]]; then
        if ! diff -q "$GITCONFIG_TEMP" "$GITCONFIG_TARGET" > /dev/null 2>&1; then
            log_warn ".gitconfig differs from expected. Creating backup..."
            backup_file "$GITCONFIG_TARGET"
            cp "$GITCONFIG_TEMP" "$GITCONFIG_TARGET"
            state_add_file "$FEATURE_NAME" "$GITCONFIG_TARGET"
            log_success ".gitconfig updated"
        else
            log_info ".gitconfig is up-to-date"
        fi
    else
        cp "$GITCONFIG_TEMP" "$GITCONFIG_TARGET"
        state_add_file "$FEATURE_NAME" "$GITCONFIG_TARGET"
        log_success ".gitconfig created"
    fi
    
    rm -f "$GITCONFIG_TEMP"
fi

# Deploy .config/git/ignore
if [[ -f "$FEATURE_FILES_DIR/ignore" ]]; then
    link_file "$FEATURE_NAME" "$FEATURE_FILES_DIR/ignore" "$TARGET_HOME/.config/git/ignore"
fi

log_success "Feature $FEATURE_NAME installed successfully"
