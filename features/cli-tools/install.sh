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

FEATURE_NAME="cli-tools"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# List of tools to install
TOOLS=(
    "fd"
    "fzf"
    "ghq"
    "ripgrep"
    "unzip"
)

# Install each tool
for tool in "${TOOLS[@]}"; do
    if has_command "$tool"; then
        log_info "$tool is already installed"
    else
        log_info "Installing $tool..."
        install_package "$tool"
        log_success "$tool installed"
    fi
    state_add_package "$FEATURE_NAME" "$tool"
done

log_success "Feature $FEATURE_NAME installed successfully"
