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

FEATURE_NAME="rust"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Install Rust via mise
if has_runtime "rust" "1.87.0"; then
    log_info "rust@1.87.0 is already installed"
else
    log_info "Installing rust@1.87.0 via mise..."
    install_runtime "rust" "1.87.0"
    log_success "rust@1.87.0 installed"
fi
state_add_package "$FEATURE_NAME" "rust@1.87.0"

# Install rust-analyzer via mise
if has_runtime "rust-analyzer" "2025-05-26"; then
    log_info "rust-analyzer@2025-05-26 is already installed"
else
    log_info "Installing rust-analyzer@2025-05-26 via mise..."
    install_runtime "rust-analyzer" "2025-05-26"
    log_success "rust-analyzer@2025-05-26 installed"
fi
state_add_package "$FEATURE_NAME" "rust-analyzer@2025-05-26"

log_success "Feature $FEATURE_NAME installed successfully"
