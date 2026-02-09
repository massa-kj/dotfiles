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

FEATURE_NAME="python"

log_task "Uninstalling feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Get installed packages from state
mapfile -t packages < <(state_get_packages "$FEATURE_NAME")

# Remove packages
for pkg in "${packages[@]}"; do
    if [[ -z "$pkg" ]]; then
        continue
    fi

    if [[ "$pkg" == "uv:"* ]]; then
        # uv package
        local uv_pkg="${pkg#uv:}"
        if uv pip list 2>/dev/null | grep -q "$uv_pkg"; then
            log_info "Removing uv package: $uv_pkg"
            uv pip uninstall --system "$uv_pkg"
        fi
    elif [[ "$pkg" == *"@"* ]]; then
        # Runtime package (python@version or uv@version)
        name="${pkg%%@*}"
        version="${pkg##*@}"
        
        if has_runtime "$name" "$version"; then
            log_info "Removing runtime: $name@$version"
            remove_runtime "$name" "$version"
        fi
    fi
done

# Remove feature from state
state_remove_feature "$FEATURE_NAME"

log_success "Feature $FEATURE_NAME uninstalled successfully"
