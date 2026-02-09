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

FEATURE_NAME="lua"

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

    # Check if it's a runtime or regular package
    if [[ "$pkg" == *"@"* ]]; then
        # Runtime package (e.g., stylua@2.1.0)
        local name="${pkg%%@*}"
        local version="${pkg##*@}"
        
        if has_runtime "$name" "$version"; then
            log_info "Removing runtime: $name@$version"
            remove_runtime "$name" "$version"
        fi
    else
        # Regular package
        if has_package "$pkg"; then
            log_info "Removing package: $pkg"
            remove_package "$pkg"
        fi
    fi
done

# Remove feature from state
state_remove_feature "$FEATURE_NAME"

log_success "Feature $FEATURE_NAME uninstalled successfully"
