#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="node"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized (needed for state_add_package below)
state_init

# node runtime installation is handled by executor (declared in meta.yaml runtimes).
# Activate mise so that node/npm installed by executor are available in PATH.
if has_command "mise"; then
    eval "$(mise activate bash 2>/dev/null)" || true
fi

# Install npm global packages (secondary package manager; tracked as npm:* in state).
# These are not managed by brew/mise and are handled here directly.
declare -a npm_packages=(
    "typescript"
    "typescript-language-server"
    "eslint"
)

if ! has_command "npm"; then
    log_warn "npm not found in PATH; skipping npm global package installation"
else
    for pkg in "${npm_packages[@]}"; do
        if npm list -g "$pkg" >/dev/null 2>&1; then
            log_info "npm package already installed: $pkg"
        else
            log_info "Installing npm package: $pkg"
            npm install -g "$pkg"
            log_success "npm package installed: $pkg"
        fi
        state_add_package "$FEATURE_NAME" "npm:$pkg"
    done
fi

log_success "Feature $FEATURE_NAME installed successfully"
