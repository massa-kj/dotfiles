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

log_task "Uninstalling feature: $FEATURE_NAME"

# Ensure state is loaded (needed to read npm: packages below)
state_init

# Activate mise so that npm is available in PATH
if has_command "mise"; then
    eval "$(mise activate bash 2>/dev/null)" || true
fi

# Remove npm global packages tracked in state (npm:* entries)
mapfile -t packages < <(state_get_packages "$FEATURE_NAME")
for pkg in "${packages[@]}"; do
    [[ -z "$pkg" ]] && continue
    if [[ "$pkg" == "npm:"* ]]; then
        npm_pkg="${pkg#npm:}"
        if has_command "npm" && npm list -g "$npm_pkg" >/dev/null 2>&1; then
            log_info "Removing npm package: $npm_pkg"
            npm uninstall -g "$npm_pkg"
        fi
    fi
done

# node runtime and feature state removal are handled by executor.

log_success "Feature $FEATURE_NAME uninstalled successfully"
