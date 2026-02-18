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

FEATURE_NAME="neovim"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Read version from profile config (optional for neovim)
VERSION="${DOTFILES_FEATURE_CONFIG_VERSION:-latest}"
if [[ "$VERSION" != "latest" ]]; then
    log_info "Target Neovim version: $VERSION"
fi

# Check if neovim is already installed
if has_command "nvim"; then
    log_info "neovim is already installed"
else
    log_info "Installing neovim package..."
    install_package "neovim"
    log_success "neovim package installed"
fi
state_add_package "$FEATURE_NAME" "neovim"

# Record version in state if specified
if [[ "$VERSION" != "latest" ]]; then
    state_set_runtime "$FEATURE_NAME" "version" "$VERSION"
fi

# Deploy configuration files
FEATURE_FILES_DIR="$SCRIPT_DIR/files/nvim"
TARGET_NVIM_DIR="$HOME/.config/nvim"

if [[ -d "$FEATURE_FILES_DIR" ]]; then
    log_info "Deploying Neovim configuration..."
    link_dir "$FEATURE_NAME" "$FEATURE_FILES_DIR" "$TARGET_NVIM_DIR"
fi

log_success "Feature $FEATURE_NAME installed successfully"
log_info "Run 'nvim' to install plugins automatically"
