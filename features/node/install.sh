#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/package.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="node"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Read version from profile config (fallback to latest)
VERSION="${DOTFILES_FEATURE_CONFIG_VERSION:-latest}"
log_info "Target Node.js version: $VERSION"

# Install Node.js via mise
if has_runtime "node" "$VERSION"; then
    log_info "node@$VERSION is already installed"
else
    log_info "Installing node@$VERSION via mise..."
    install_runtime "node" "$VERSION"
    log_success "node@$VERSION installed"
fi
state_add_package "$FEATURE_NAME" "node@$VERSION"

# Record version in state
state_set_runtime "$FEATURE_NAME" "version" "$VERSION"

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
