#!/usr/bin/env bash
# State operation API

# Dependencies: jq, core/env.sh, core/lib/logger.sh

# Initialize state
state_init() {
    if [[ -z "$DOTFILES_STATE_FILE" ]]; then
        log_error "DOTFILES_STATE_FILE is not set"
        return 1
    fi

    # Create state directory if it doesn't exist
    local state_dir
    state_dir="$(dirname "$DOTFILES_STATE_FILE")"
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir"
    fi

    # Initialize state file if it doesn't exist
    if [[ ! -f "$DOTFILES_STATE_FILE" ]]; then
        echo '{"version":1,"features":{}}' > "$DOTFILES_STATE_FILE"
    fi

    # Validate JSON
    if ! jq empty "$DOTFILES_STATE_FILE" 2>/dev/null; then
        log_error "state file is corrupted: $DOTFILES_STATE_FILE"
        return 1
    fi
}

# Check if feature exists
state_has_feature() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_has_feature: feature name is required"
        return 1
    fi

    jq -e ".features[\"$feature\"] != null" "$DOTFILES_STATE_FILE" >/dev/null 2>&1
}

# Add package to feature
state_add_package() {
    local feature="$1"
    local package="$2"

    if [[ -z "$feature" ]] || [[ -z "$package" ]]; then
        log_error "state_add_package: feature and package are required"
        return 1
    fi

    local tmp_file="${DOTFILES_STATE_FILE}.tmp"

    # Initialize feature if it doesn't exist
    if ! state_has_feature "$feature"; then
        jq ".features[\"$feature\"] = {\"packages\": [], \"files\": []}" \
            "$DOTFILES_STATE_FILE" > "$tmp_file"
        mv "$tmp_file" "$DOTFILES_STATE_FILE"
    fi

    # Add package (with deduplication)
    jq ".features[\"$feature\"].packages |= (. + [\"$package\"] | unique)" \
        "$DOTFILES_STATE_FILE" > "$tmp_file"
    
    if [[ $? -ne 0 ]]; then
        log_error "state_add_package: failed to add package"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$DOTFILES_STATE_FILE"
}

# Add file to feature
state_add_file() {
    local feature="$1"
    local file="$2"

    if [[ -z "$feature" ]] || [[ -z "$file" ]]; then
        log_error "state_add_file: feature and file are required"
        return 1
    fi

    local tmp_file="${DOTFILES_STATE_FILE}.tmp"

    # Initialize feature if it doesn't exist
    if ! state_has_feature "$feature"; then
        jq ".features[\"$feature\"] = {\"packages\": [], \"files\": []}" \
            "$DOTFILES_STATE_FILE" > "$tmp_file"
        mv "$tmp_file" "$DOTFILES_STATE_FILE"
    fi

    # Add file (with deduplication)
    jq ".features[\"$feature\"].files |= (. + [\"$file\"] | unique)" \
        "$DOTFILES_STATE_FILE" > "$tmp_file"
    
    if [[ $? -ne 0 ]]; then
        log_error "state_add_file: failed to add file"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$DOTFILES_STATE_FILE"
}

# Get list of packages for feature
state_get_packages() {
    local feature="$1"

    if [[ -z "$feature" ]]; then
        log_error "state_get_packages: feature name is required"
        return 1
    fi

    if ! state_has_feature "$feature"; then
        return 0
    fi

    jq -r ".features[\"$feature\"].packages[]" "$DOTFILES_STATE_FILE" 2>/dev/null
}

# Get list of files for feature
state_get_files() {
    local feature="$1"

    if [[ -z "$feature" ]]; then
        log_error "state_get_files: feature name is required"
        return 1
    fi

    if ! state_has_feature "$feature"; then
        return 0
    fi

    jq -r ".features[\"$feature\"].files[]" "$DOTFILES_STATE_FILE" 2>/dev/null
}

# Remove feature
state_remove_feature() {
    local feature="$1"

    if [[ -z "$feature" ]]; then
        log_error "state_remove_feature: feature name is required"
        return 1
    fi

    if ! state_has_feature "$feature"; then
        log_warn "state_remove_feature: feature not found: $feature"
        return 0
    fi

    local tmp_file="${DOTFILES_STATE_FILE}.tmp"

    jq "del(.features[\"$feature\"])" "$DOTFILES_STATE_FILE" > "$tmp_file"
    
    if [[ $? -ne 0 ]]; then
        log_error "state_remove_feature: failed to remove feature"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$DOTFILES_STATE_FILE"
}

# Get list of installed features
state_list_features() {
    if [[ ! -f "$DOTFILES_STATE_FILE" ]]; then
        return 0
    fi

    jq -r '.features | keys[]' "$DOTFILES_STATE_FILE" 2>/dev/null
}
