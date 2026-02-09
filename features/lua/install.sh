#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/package.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="lua"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Install luacheck
if has_package "luacheck"; then
    log_info "luacheck is already installed"
else
    log_info "Installing luacheck package..."
    install_package "luacheck"
    log_success "luacheck package installed"
fi
state_add_package "$FEATURE_NAME" "luacheck"

# Install stylua
if has_runtime "stylua" "2.1.0"; then
    log_info "stylua@2.1.0 is already installed"
else
    log_info "Installing stylua@2.1.0 via mise..."
    install_runtime "stylua" "2.1.0"
    log_success "stylua@2.1.0 installed"
fi
state_add_package "$FEATURE_NAME" "stylua@2.1.0"

# Install lua-language-server
if has_runtime "lua-language-server" "3.14.0"; then
    log_info "lua-language-server@3.14.0 is already installed"
else
    log_info "Installing lua-language-server@3.14.0 via mise..."
    install_runtime "lua-language-server" "3.14.0"
    log_success "lua-language-server@3.14.0 installed"
fi
state_add_package "$FEATURE_NAME" "lua-language-server@3.14.0"

log_success "Feature $FEATURE_NAME installed successfully"
