#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/package.sh"
source "$DOTFILES_ROOT/core/lib/fs.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="tmux"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Check if tmux is already installed
if has_command "tmux"; then
    log_info "tmux is already installed"
else
    log_info "Installing tmux package..."
    install_package "tmux"
    log_success "tmux package installed"
fi
state_add_package "$FEATURE_NAME" "tmux"

# Deploy configuration files
FEATURE_FILES_DIR="$SCRIPT_DIR/files"
TARGET_HOME="${HOME}"

if [[ -d "$FEATURE_FILES_DIR" ]]; then
    log_info "Deploying tmux configuration files..."
    
    # Deploy .tmux.conf if exists
    if [[ -f "$FEATURE_FILES_DIR/.tmux.conf" ]]; then
        link_file "$FEATURE_NAME" "$FEATURE_FILES_DIR/.tmux.conf" "$TARGET_HOME/.tmux.conf"
    fi
fi

log_success "Feature $FEATURE_NAME installed successfully"
