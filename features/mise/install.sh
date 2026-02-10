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

FEATURE_NAME="mise"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Check if mise is already installed
if has_command "mise"; then
    log_info "mise is already installed"
else
    log_info "Installing mise package..."
    install_package "mise"
    log_success "mise package installed"
fi
state_add_package "$FEATURE_NAME" "mise"

# Deploy configuration files
FEATURE_FILES_DIR="$SCRIPT_DIR/files"
TARGET_MISE_DIR="$HOME/.config/mise"

if [[ -d "$FEATURE_FILES_DIR" ]]; then
    log_info "Deploying mise configuration..."
    
    # Deploy config.toml if exists
    if [[ -f "$FEATURE_FILES_DIR/config.toml" ]]; then
        link_file "$FEATURE_NAME" "$FEATURE_FILES_DIR/config.toml" "$TARGET_MISE_DIR/config.toml"
    fi
fi

log_success "Feature $FEATURE_NAME installed successfully"
log_info "Reload your shell or run: mise activate"
