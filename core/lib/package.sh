#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: package
#
# Responsibility:
#   Provide package manager abstraction for system packages and runtimes.
#
# Public API (Stable):
#   install_package <name>
#   remove_package <name>
#   install_runtime <name> <version>
#   remove_runtime <name> [version]
#   has_package <name>
#   has_runtime <name> [version]
#   resolve_runtime_version <name> <version>
# -----------------------------------------------------------------------------

# This library expects core/env.sh and core/lib/logger.sh to be sourced by the caller.

# Global variable to cache brew path
_BREW_PATH=""

# _ensure_brew_available
# Ensure brew is available in PATH.
_ensure_brew_available() {
    # Already in PATH
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi
    
    # Check standard Linux installation location
    if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        _BREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"
        return 0
    fi
    
    return 1
}

# Select package manager based on platform and availability
_detect_package_manager() {
    # Ensure brew is available if it exists
    if _ensure_brew_available; then
        echo "brew"
        return 0
    fi

    # Fallbacks
    # if command -v apt-get >/dev/null 2>&1; then
    #     echo "apt"
    #     return 0
    # fi

    log_error "No supported package manager found"
    return 1
}

# has_package <name>
# Check if a package is installed.
has_package() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "has_package: package name is required"
        return 1
    fi

    local manager
    manager="$(_detect_package_manager)" || return 1

    case "$manager" in
        brew)
            _ensure_brew_available
            brew list --formula --versions "$name" >/dev/null 2>&1
            return $?
            ;;
        apt)
            dpkg -s "$name" >/dev/null 2>&1
            return $?
            ;;
        *)
            log_error "has_package: unsupported manager: $manager"
            return 1
            ;;
    esac
}

# install_package <name>
# Install a package using detected package manager.
install_package() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "install_package: package name is required"
        return 1
    fi

    if has_package "$name"; then
        log_info "Package already installed: $name"
        return 0
    fi

    local manager
    manager="$(_detect_package_manager)" || return 1

    log_info "Installing package ($manager): $name"

    case "$manager" in
        brew)
            _ensure_brew_available
            brew install "$name"
            ;;
        apt)
            sudo apt-get install -y "$name"
            ;;
        *)
            log_error "install_package: unsupported manager: $manager"
            return 1
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        log_error "Failed to install package: $name"
        return 1
    fi

    return 0
}

# remove_package <name>
# Remove a package using detected package manager.
remove_package() {
    local name="$1"
    if [[ -z "$name" ]]; then
        log_error "remove_package: package name is required"
        return 1
    fi

    if ! has_package "$name"; then
        log_info "Package not installed: $name"
        return 0
    fi

    local manager
    manager="$(_detect_package_manager)" || return 1

    log_info "Removing package ($manager): $name"

    case "$manager" in
        brew)
            _ensure_brew_available
            brew uninstall "$name"
            ;;
        apt)
            sudo apt-get remove -y "$name"
            ;;
        *)
            log_error "remove_package: unsupported manager: $manager"
            return 1
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        log_error "Failed to remove package: $name"
        return 1
    fi

    return 0
}

# _ensure_mise_available
# Ensure mise is available in PATH.
_ensure_mise_available() {
    # Already in PATH
    if command -v mise >/dev/null 2>&1; then
        return 0
    fi
    
    # Check common installation locations
    local mise_paths=(
        "$HOME/.local/bin/mise"
        "/home/linuxbrew/.linuxbrew/bin/mise"
        "/usr/local/bin/mise"
    )
    
    for mise_path in "${mise_paths[@]}"; do
        if [[ -x "$mise_path" ]]; then
            # Add to PATH
            export PATH="$(dirname "$mise_path"):$PATH"
            
            # Activate mise for current shell
            eval "$("$mise_path" activate bash)"
            return 0
        fi
    done
    
    return 1
}

# resolve_runtime_version <name> <version>
# Resolve a runtime version alias (e.g. "latest", "20") to the actual version number.
# Prints the resolved version to stdout.
resolve_runtime_version() {
    local name="$1"
    local version="$2"

    if [[ -z "$name" ]] || [[ -z "$version" ]]; then
        log_error "resolve_runtime_version: runtime name and version are required"
        return 1
    fi

    if ! _ensure_mise_available; then
        log_error "mise is not available"
        return 1
    fi

    # If already a concreate version, return as is
    if [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        echo "$version"
        return 0
    fi
    
    # Resolve alias to actual version using mise
    local resolved_version
    resolved_version=$(mise latest "$name@$version" 2>/dev/null)
    if [[ -n "$resolved_version" ]]; then
        echo "$resolved_version"
        return 0
    fi
    
    # Fallback: return as is
    echo "$version"
}

# has_runtime <name> [version]
# Check if a runtime is installed via mise.
has_runtime() {
    local name="$1"
    local version="${2:-}"

    if [[ -z "$name" ]]; then
        log_error "has_runtime: runtime name is required"
        return 1
    fi

    if ! _ensure_mise_available; then
        log_error "mise is not available"
        return 1
    fi

    if [[ -n "$version" ]]; then
        # Resolve alias to actual version for checking
        local resolved_version
        resolved_version=$(resolve_runtime_version "$name" "$version")
        mise where "$name@$resolved_version" >/dev/null 2>&1
        return $?
    fi

    mise ls --installed "$name" >/dev/null 2>&1
    return $?
}

# install_runtime <name> <version>
# Install a runtime via mise and set as global default.
# Prints the actual installed version to stdout.
install_runtime() {
    local name="$1"
    local version="$2"

    if [[ -z "$name" ]] || [[ -z "$version" ]]; then
        log_error "install_runtime: runtime name and version are required"
        return 1
    fi

    if ! _ensure_mise_available; then
        log_error "mise is not available"
        return 1
    fi
    
    # Resolve alias to actual version
    local resolved_version
    resolved_version=$(resolve_runtime_version "$name" "$version")

    if has_runtime "$name" "$resolved_version"; then
        log_info "Runtime already installed: $name@$resolved_version"
        echo "$resolved_version"
        return 0
    fi

    log_info "Installing runtime: $name@$resolved_version"
    mise install "$name@$resolved_version" >&2

    if [[ $? -ne 0 ]]; then
        log_error "Failed to install runtime: $name@$resolved_version"
        return 1
    fi

    log_info "Setting global runtime: $name@$resolved_version"
    mise use -g "$name@$resolved_version" >&2
    
    # Ensure the newly installed runtime is available in current shell
    local runtime_path
    runtime_path=$(mise where "$name@$resolved_version" 2>/dev/null || true)
    if [[ -n "$runtime_path" ]]; then
        # Add runtime bin directory to PATH
        if [[ -d "$runtime_path/bin" ]]; then
            export PATH="$runtime_path/bin:$PATH"
            log_info "Added $name@$resolved_version to PATH: $runtime_path/bin"
        fi
    fi
    
    # Re-activate mise to ensure all shims are updated
    eval "$(mise activate bash)" >&2
    
    echo "$resolved_version"
}

# remove_runtime <name> [version]
# Remove a runtime via mise.
remove_runtime() {
    local name="$1"
    local version="${2:-}"

    if [[ -z "$name" ]]; then
        log_error "remove_runtime: runtime name is required"
        return 1
    fi

    if ! _ensure_mise_available; then
        log_error "mise is not available"
        return 1
    fi

    if [[ -n "$version" ]]; then
        if ! has_runtime "$name" "$version"; then
            log_info "Runtime not installed: $name@$version"
            return 0
        fi

        log_info "Removing runtime: $name@$version"
        mise uninstall "$name@$version"
    else
        if ! has_runtime "$name"; then
            log_info "Runtime not installed: $name"
            return 0
        fi

        log_info "Removing runtime: $name"
        mise uninstall "$name"
    fi

    if [[ $? -ne 0 ]]; then
        log_error "Failed to remove runtime: $name${version:+@$version}"
        return 1
    fi

    return 0
}
