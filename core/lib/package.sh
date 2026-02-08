#!/usr/bin/env bash
# Package manager abstraction

# This library expects core/env.sh and core/lib/logger.sh to be sourced by the caller.

# Select package manager based on platform and availability
_detect_package_manager() {
    if command -v brew >/dev/null 2>&1; then
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

# Check if a package is installed
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

# Install a package
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

# Remove a package
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

# Check if a runtime is installed via mise
has_runtime() {
    local name="$1"
    local version="${2:-}"

    if [[ -z "$name" ]]; then
        log_error "has_runtime: runtime name is required"
        return 1
    fi

    if ! command -v mise >/dev/null 2>&1; then
        log_error "mise is not available"
        return 1
    fi

    if [[ -n "$version" ]]; then
        mise where "$name@$version" >/dev/null 2>&1
        return $?
    fi

    mise ls --installed "$name" >/dev/null 2>&1
    return $?
}

# Install a runtime via mise
install_runtime() {
    local name="$1"
    local version="$2"

    if [[ -z "$name" ]] || [[ -z "$version" ]]; then
        log_error "install_runtime: runtime name and version are required"
        return 1
    fi

    if ! command -v mise >/dev/null 2>&1; then
        log_error "mise is not available"
        return 1
    fi

    if has_runtime "$name" "$version"; then
        log_info "Runtime already installed: $name@$version"
        return 0
    fi

    log_info "Installing runtime: $name@$version"
    mise install "$name@$version"

    if [[ $? -ne 0 ]]; then
        log_error "Failed to install runtime: $name@$version"
        return 1
    fi

    log_info "Setting global runtime: $name@$version"
    mise use -g "$name@$version"
}

# Remove a runtime via mise
remove_runtime() {
    local name="$1"
    local version="${2:-}"

    if [[ -z "$name" ]]; then
        log_error "remove_runtime: runtime name is required"
        return 1
    fi

    if ! command -v mise >/dev/null 2>&1; then
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
