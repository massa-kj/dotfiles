#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: state
#
# Responsibility:
#   Manage state file operations safely with atomic updates.
#
# Public API (Stable):
#   state_init
#   state_has_feature <feature>
#   state_add_package <feature> <package>
#   state_add_file <feature> <path>
#   state_get_packages <feature>
#   state_get_files <feature>
#   state_has_file <path>
#   state_remove_feature <feature>
#   state_list_features
#   state_set_runtime <feature> <key> <value>
#   state_get_runtime <feature> <key>
#   state_has_runtime <feature> <key>
# -----------------------------------------------------------------------------

# state_init
# Initialize or validate state file.
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

# state_has_feature <feature>
# Check if a feature exists in state.
state_has_feature() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_has_feature: feature name is required"
        return 1
    fi

    jq -e ".features[\"$feature\"] != null" "$DOTFILES_STATE_FILE" >/dev/null 2>&1
}

# state_add_package <feature> <package>
# Register a package for a feature with deduplication.
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

# state_add_file <feature> <path>
# Register a file path for a feature with deduplication.
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

# state_get_packages <feature>
# Retrieve package list for a feature (one per line).
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

# state_get_files <feature>
# Retrieve file path list for a feature (one per line).
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

# state_has_file <path>
# Check if a file path is registered under any feature.
state_has_file() {
    local path="$1"

    if [[ -z "$path" ]]; then
        log_error "state_has_file: path is required"
        return 1
    fi

    jq -e --arg p "$path" \
        '[.features | to_entries[] | .value.files[]] | index($p) != null' \
        "$DOTFILES_STATE_FILE" >/dev/null 2>&1
}

# state_remove_feature <feature>
# Remove a feature entry from state.
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

# state_list_features
# Retrieve all installed feature names (one per line).
state_list_features() {
    if [[ ! -f "$DOTFILES_STATE_FILE" ]]; then
        return 0
    fi

    jq -r '.features | keys[]' "$DOTFILES_STATE_FILE" 2>/dev/null
}

# state_set_runtime <feature> <key> <value>
# Set runtime metadata for a feature.
state_set_runtime() {
    local feature="$1"
    local key="$2"
    local value="$3"

    if [[ -z "$feature" ]] || [[ -z "$key" ]]; then
        log_error "state_set_runtime: feature and key are required"
        return 1
    fi

    local tmp_file="${DOTFILES_STATE_FILE}.tmp"

    # Initialize feature if it doesn't exist
    if ! state_has_feature "$feature"; then
        jq ".features[\"$feature\"] = {\"packages\": [], \"files\": []}" \
            "$DOTFILES_STATE_FILE" > "$tmp_file"
        mv "$tmp_file" "$DOTFILES_STATE_FILE"
    fi

    # Initialize runtime object if it doesn't exist
    if ! jq -e ".features[\"$feature\"].runtime" "$DOTFILES_STATE_FILE" >/dev/null 2>&1; then
        jq ".features[\"$feature\"].runtime = {}" \
            "$DOTFILES_STATE_FILE" > "$tmp_file"
        mv "$tmp_file" "$DOTFILES_STATE_FILE"
    fi

    # Set runtime metadata
    jq ".features[\"$feature\"].runtime[\"$key\"] = \"$value\"" \
        "$DOTFILES_STATE_FILE" > "$tmp_file"
    
    if [[ $? -ne 0 ]]; then
        log_error "state_set_runtime: failed to set runtime metadata"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$DOTFILES_STATE_FILE"
}

# state_get_runtime <feature> <key>
# Get runtime metadata for a feature.
state_get_runtime() {
    local feature="$1"
    local key="$2"

    if [[ -z "$feature" ]] || [[ -z "$key" ]]; then
        log_error "state_get_runtime: feature and key are required"
        return 1
    fi

    if ! state_has_feature "$feature"; then
        return 0
    fi

    # Safe access with empty fallback
    jq -r ".features[\"$feature\"].runtime.\"$key\" // empty" "$DOTFILES_STATE_FILE" 2>/dev/null
}

# state_has_runtime <feature> <key>
# Check if runtime metadata exists for a feature.
state_has_runtime() {
    local feature="$1"
    local key="$2"

    if [[ -z "$feature" ]] || [[ -z "$key" ]]; then
        log_error "state_has_runtime: feature and key are required"
        return 1
    fi

    if ! state_has_feature "$feature"; then
        return 1
    fi

    jq -e ".features[\"$feature\"].runtime.\"$key\" != null" "$DOTFILES_STATE_FILE" >/dev/null 2>&1
}
