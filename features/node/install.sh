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

FEATURE_NAME="node"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Install Node.js via mise
if has_runtime "node" "22.17.1"; then
    log_info "node@22.17.1 is already installed"
else
    log_info "Installing node@22.17.1 via mise..."
    install_runtime "node" "22.17.1"
    log_success "node@22.17.1 installed"
fi
state_add_package "$FEATURE_NAME" "node@22.17.1"

# Install npm packages
declare -a npm_packages=(
    "typescript"
    "typescript-language-server"
    "eslint"
)

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

log_success "Feature $FEATURE_NAME installed successfully"
