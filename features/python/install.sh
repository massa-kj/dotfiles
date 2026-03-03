#!/usr/bin/env bash

set -euo pipefail

# Load core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DOTFILES_ROOT/core/lib/env.sh"
source "$DOTFILES_ROOT/core/lib/logger.sh"
source "$DOTFILES_ROOT/core/lib/state.sh"
source "$DOTFILES_ROOT/core/lib/runner.sh"

FEATURE_NAME="python"

log_task "Installing feature: $FEATURE_NAME"

# Ensure state is initialized (needed for state_add_package below)
state_init

# python and uv runtime installations are handled by executor (declared in meta.yaml runtimes).
# Activate mise so that python/uv installed by executor are available in PATH.
if has_command "mise"; then
    eval "$(mise activate bash 2>/dev/null)" || true
fi

# Install python-lsp-server via uv (secondary package manager; tracked as uv:* in state).
if ! has_command "uv"; then
    log_warn "uv not found in PATH; skipping python-lsp-server installation"
else
    if uv pip list 2>/dev/null | grep -q "python-lsp-server"; then
        log_info "python-lsp-server already installed"
    else
        log_info "Installing python-lsp-server via uv..."
        uv pip install --system python-lsp-server
        log_success "python-lsp-server installed"
    fi
    state_add_package "$FEATURE_NAME" "uv:python-lsp-server"
fi

log_success "Feature $FEATURE_NAME installed successfully"
