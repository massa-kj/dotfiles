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

FEATURE_NAME="python"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Install Python via mise
if has_runtime "python" "3.12"; then
    log_info "python@3.12 is already installed"
else
    log_info "Installing python@3.12 via mise..."
    install_runtime "python" "3.12"
    log_success "python@3.12 installed"
fi
state_add_package "$FEATURE_NAME" "python@3.12"

# Install uv via mise
if has_runtime "uv" "latest"; then
    log_info "uv@latest is already installed"
else
    log_info "Installing uv@latest via mise..."
    install_runtime "uv" "latest"
    log_success "uv@latest installed"
fi
state_add_package "$FEATURE_NAME" "uv@latest"

# Install python-lsp-server via uv
if uv pip list 2>/dev/null | grep -q "python-lsp-server"; then
    log_info "python-lsp-server already installed"
else
    log_info "Installing python-lsp-server via uv..."
    uv pip install --system python-lsp-server
    log_success "python-lsp-server installed"
fi
state_add_package "$FEATURE_NAME" "uv:python-lsp-server"

log_success "Feature $FEATURE_NAME installed successfully"
