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

log_task "Uninstalling feature: $FEATURE_NAME"

# Ensure state is loaded (needed to read uv: packages below)
state_init

# Activate mise so that uv is available in PATH
if has_command "mise"; then
    eval "$(mise activate bash 2>/dev/null)" || true
fi

# Remove uv packages tracked in state (uv:* entries)
mapfile -t packages < <(state_get_packages "$FEATURE_NAME")
for pkg in "${packages[@]}"; do
    [[ -z "$pkg" ]] && continue
    if [[ "$pkg" == "uv:"* ]]; then
        uv_pkg="${pkg#uv:}"
        if has_command "uv" && uv pip list 2>/dev/null | grep -q "^${uv_pkg} "; then
            log_info "Removing uv package: $uv_pkg"
            uv pip uninstall --system "$uv_pkg"
        fi
    fi
done

# python/uv runtimes and feature state removal are handled by executor.

log_success "Feature $FEATURE_NAME uninstalled successfully"
