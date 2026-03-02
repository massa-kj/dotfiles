#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: package
#
# DEPRECATED — Will be removed in Phase 4.
# All functions now delegate to backend_registry.sh.
# Feature scripts should continue calling these as-is until Phase 4 migrates
# them to use backend_registry directly.
#
# Public API (Stable — preserved for compat):
#   install_package <name>
#   remove_package <name>
#   install_runtime <name> <version>
#   remove_runtime <name> [version]
#   has_package <name>
#   has_runtime <name> [version]
#   resolve_runtime_version <name> <version>
# -----------------------------------------------------------------------------

# This library expects env.sh and logger.sh to be sourced by the caller.

# Source backend_registry if not already loaded
if [[ "$(type -t backend_registry_load_policy)" != "function" ]]; then
    # shellcheck source=core/lib/backend_registry.sh
    source "${DOTFILES_ROOT}/core/lib/backend_registry.sh"
fi

# ── Package API ───────────────────────────────────────────────────────────────

# has_package <name>
# Check if a system package is installed.
has_package() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "has_package: package name is required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "package" "$name") || return 1
    load_backend "$backend" || return 1
    backend_call "package_exists" "$name"
}

# install_package <name>
# Install a system package using the policy-resolved backend.
install_package() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "install_package: package name is required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "package" "$name") || return 1
    load_backend "$backend" || return 1
    backend_call "install_package" "$name"
}

# remove_package <name>
# Remove a system package using the policy-resolved backend.
remove_package() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "remove_package: package name is required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "package" "$name") || return 1
    load_backend "$backend" || return 1
    backend_call "uninstall_package" "$name"
}

# ── Runtime API ───────────────────────────────────────────────────────────────

# resolve_runtime_version <name> <version>
# Resolve a runtime version alias to a concrete version string.
# Prints the resolved version to stdout.
resolve_runtime_version() {
    local name="$1"
    local version="$2"

    if [[ -z "$name" ]] || [[ -z "$version" ]]; then
        log_error "resolve_runtime_version: name and version are required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "runtime" "$name") || return 1
    load_backend "$backend" || return 1

    # If already a concrete version forward it through the backend resolver
    if [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        echo "$version"
        return 0
    fi

    if command -v mise >/dev/null 2>&1; then
        local resolved
        resolved=$(mise latest "${name}@${version}" 2>/dev/null)
        if [[ -n "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi
    fi

    echo "$version"
}

# has_runtime <name> [version]
# Check if a runtime version is installed via the policy-resolved backend.
has_runtime() {
    local name="$1"
    local version="${2:-}"

    if [[ -z "$name" ]]; then
        log_error "has_runtime: runtime name is required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "runtime" "$name") || return 1
    load_backend "$backend" || return 1
    backend_call "runtime_exists" "$name" "$version"
}

# install_runtime <name> <version>
# Install a runtime via the policy-resolved backend and set as global default.
# Prints the concrete resolved version to stdout.
install_runtime() {
    local name="$1"
    local version="$2"

    if [[ -z "$name" ]] || [[ -z "$version" ]]; then
        log_error "install_runtime: name and version are required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "runtime" "$name") || return 1
    load_backend "$backend" || return 1
    # backend echoes the concrete resolved version to stdout
    backend_call "install_runtime" "$name" "$version"
}

# remove_runtime <name> [version]
# Remove a runtime via the policy-resolved backend.
remove_runtime() {
    local name="$1"
    local version="${2:-}"

    if [[ -z "$name" ]]; then
        log_error "remove_runtime: runtime name is required"
        return 1
    fi

    local backend
    backend=$(resolve_backend_for "runtime" "$name") || return 1
    load_backend "$backend" || return 1
    backend_call "uninstall_runtime" "$name" "$version"
}
