#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: fs
#
# Responsibility:
#   Provide file system operations for feature installation.
#
# Public API (Stable):
#   ensure_dir <path>
#   backup_file <target>
#   backup_dir <target>
#   link_file <feature> <src> <dst>
#   link_dir <feature> <src> <dst>
#   remove_tracked_files <feature>
# -----------------------------------------------------------------------------

# This library expects core/lib/logger.sh and core/lib/state.sh to be sourced by the caller.

# ensure_dir <path>
# Create directory if it does not exist.
ensure_dir() {
    local path="$1"

    if [[ -z "$path" ]]; then
        log_error "ensure_dir: path is required"
        return 1
    fi

    if [[ ! -d "$path" ]]; then
        mkdir -p "$path"
    fi
}

# backup_file <target>
# Backup existing file with timestamp if it exists and is not a symlink.
backup_file() {
    local target="$1"

    if [[ -z "$target" ]]; then
        log_error "backup_file: target is required"
        return 1
    fi

    if [[ -f "$target" ]] && [[ ! -L "$target" ]]; then
        local backup_path="${target}.backup"
        if [[ -e "$backup_path" ]]; then
            backup_path="${target}.backup.$(date +%Y%m%d%H%M%S)"
        fi
        log_warn "Backing up existing $target to $backup_path"
        mv "$target" "$backup_path"
    fi
}

# backup_dir <target>
# Backup existing directory with timestamp if it exists and is not a symlink.
backup_dir() {
    local target="$1"

    if [[ -z "$target" ]]; then
        log_error "backup_dir: target is required"
        return 1
    fi

    if [[ -d "$target" ]] && [[ ! -L "$target" ]]; then
        local backup_path="${target}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Backing up existing directory $target to $backup_path"
        mv "$target" "$backup_path"
    fi
}

# link_file <feature> <src> <dst>
# Create symbolic link for file and register to state.
link_file() {
    local feature="$1"
    local src="$2"
    local dst="$3"

    if [[ -z "$feature" ]] || [[ -z "$src" ]] || [[ -z "$dst" ]]; then
        log_error "link_file: feature, src, and dst are required"
        return 1
    fi

    if [[ ! -f "$src" ]]; then
        log_error "link_file: source file not found: $src"
        return 1
    fi

    ensure_dir "$(dirname "$dst")"
    backup_file "$dst"

    ln -sf "$src" "$dst"
    state_add_file "$feature" "$dst"
    log_success "Linked $dst"
}

# link_dir <feature> <src> <dst>
# Create symbolic link for directory and register to state.
link_dir() {
    local feature="$1"
    local src="$2"
    local dst="$3"

    if [[ -z "$feature" ]] || [[ -z "$src" ]] || [[ -z "$dst" ]]; then
        log_error "link_dir: feature, src, and dst are required"
        return 1
    fi

    if [[ ! -d "$src" ]]; then
        log_error "link_dir: source directory not found: $src"
        return 1
    fi

    ensure_dir "$(dirname "$dst")"
    backup_dir "$dst"

    # Remove if it's a symlink to a different location
    if [[ -L "$dst" ]]; then
        rm -f "$dst"
    fi

    ln -sf "$src" "$dst"
    state_add_file "$feature" "$dst"
    log_success "Linked $dst"
}

# remove_tracked_files <feature>
# Remove all files tracked by a feature from state.
remove_tracked_files() {
    local feature="$1"

    if [[ -z "$feature" ]]; then
        log_error "remove_tracked_files: feature is required"
        return 1
    fi

    log_info "Removing configuration files..."
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            if [[ -L "$file" ]]; then
                log_info "Removing symlink: $file"
                rm -f "$file"
            elif [[ -f "$file" ]] || [[ -d "$file" ]]; then
                log_warn "Path is not a symlink, skipping: $file"
            else
                log_info "Path does not exist, skipping: $file"
            fi
        fi
    done < <(state_get_files "$feature")
}
