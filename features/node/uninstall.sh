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

log_task "Uninstalling feature: $FEATURE_NAME"

# Ensure state is initialized
state_init

# Get installed packages from state
mapfile -t packages < <(state_get_packages "$FEATURE_NAME")

# Remove packages
# Remove npm packages first
for pkg in "${packages[@]}"; do
    if [[ -z "$pkg" ]]; then
        continue
    fi
    if [[ "$pkg" == "npm:"* ]]; then
        # npm package
        npm_pkg="${pkg#npm:}"
        if npm list -g "$npm_pkg" >/dev/null 2>&1; then
            log_info "Removing npm package: $npm_pkg"
            npm uninstall -g "$npm_pkg"
        fi
    fi
done

# Remove node runtimes after npm packages
for pkg in "${packages[@]}"; do
    if [[ -z "$pkg" ]]; then
        continue
    fi
    if [[ "$pkg" == *"@"* ]] && [[ "$pkg" != "npm:"* ]]; then
        # Runtime package (node@version)
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
