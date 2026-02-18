#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: orchestrator
#
# Responsibility:
#   Orchestrate feature installation and uninstallation workflow.
#
# Public API (Internal):
#   read_profile <profile_file> <output_array>
#   calculate_diff <sorted_features> <to_install> <to_uninstall>
#   run_uninstall <features>
#   run_install <features>
#   print_summary
# -----------------------------------------------------------------------------

# This library expects core/env.sh, core/lib/logger.sh, and core/lib/state.sh to be sourced by the caller.

# Global variable to cache profile data
declare -g _PROFILE_DATA=""

# read_profile <profile_file> <output_array>
# Read profile YAML file and extract feature names from map.
read_profile() {
    local profile_file="$1"
    local -n output_array=$2
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: $profile_file"
        return 1
    fi
    
    log_info "Reading profile..."
    
    # Cache full profile data for later config extraction
    _PROFILE_DATA=$(cat "$profile_file")
    
    # Extract feature names (keys from features map)
    output_array=($(yq eval '.features | keys | .[]' "$profile_file"))
    
    if [[ ${#output_array[@]} -eq 0 ]]; then
        log_warn "Empty profile (no features specified)"
        log_info "All installed features will be uninstalled"
        return 0
    fi
    
    log_info "Desired features: ${output_array[*]}"
    return 0
}

# extract_feature_config <feature>
# Extract configuration for a specific feature from cached profile data.
# Returns JSON string or empty if no config.
extract_feature_config() {
    local feature="$1"
    
    if [[ -z "$_PROFILE_DATA" ]]; then
        return 0
    fi
    
    # Extract config for the feature (returns {} if empty or null)
    echo "$_PROFILE_DATA" | yq eval ".features.${feature}" -o=json -
}

# check_version_mismatch <feature>
# Check if desired version differs from installed version.
# Returns: 0 if match/no-version, 1 if mismatch.
check_version_mismatch() {
    local feature="$1"
    
    # Get desired version from profile
    local feature_config=$(extract_feature_config "$feature")
    local desired_version=$(echo "$feature_config" | jq -r '.version // empty')
    
    # If no version specified in profile, no mismatch
    if [[ -z "$desired_version" ]]; then
        return 0
    fi
    
    # Get installed version from state
    local installed_version=$(state_get_runtime "$feature" "version")
    
    # If no installed version recorded, it's a mismatch
    if [[ -z "$installed_version" ]]; then
        return 1
    fi
    
    # Compare versions
    if [[ "$desired_version" != "$installed_version" ]]; then
        return 1
    fi
    
    return 0
}

# calculate_diff <sorted_features> <to_install> <to_uninstall> <to_reinstall>
# Calculate difference between desired and installed features.
# Includes version mismatch detection for reinstall.
calculate_diff() {
    local -n sorted_features=$1
    local -n to_install=$2
    local -n to_uninstall=$3
    local -n to_reinstall=$4
    
    local installed_features=($(state_list_features))
    
    to_install=()
    to_uninstall=()
    to_reinstall=()
    
    # Find features to install or reinstall
    for feature in "${sorted_features[@]}"; do
        if ! state_has_feature "$feature"; then
            to_install+=("$feature")
        elif ! check_version_mismatch "$feature"; then
            # Version mismatch detected
            log_info "Version mismatch detected for: $feature"
            to_reinstall+=("$feature")
        fi
    done
    
    # Find features to uninstall
    for feature in "${installed_features[@]}"; do
        if [[ ! " ${sorted_features[*]} " =~ " ${feature} " ]]; then
            to_uninstall+=("$feature")
        fi
    done
    
    log_info "Features to install: ${to_install[*]:-none}"
    log_info "Features to uninstall: ${to_uninstall[*]:-none}"
    log_info "Features to reinstall: ${to_reinstall[*]:-none}"
}

# run_uninstall <features>
# Execute uninstall scripts for features in reverse order.
run_uninstall() {
    local -n features=$1
    
    if [[ ${#features[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_task "Uninstalling features..."
    
    # Uninstall in reverse order
    for ((i=${#features[@]}-1; i>=0; i--)); do
        local feature="${features[$i]}"
        local uninstall_script="$DOTFILES_FEATURES_DIR/$feature/uninstall.sh"
        
        if [[ ! -f "$uninstall_script" ]]; then
            log_error "Uninstall script not found: $uninstall_script"
            return 1
        fi
        
        log_info "Uninstalling: $feature"
        if ! bash "$uninstall_script"; then
            log_error "Failed to uninstall: $feature"
            return 1
        fi
    done
    
    return 0
}

# run_install <features>
# Execute install scripts for features in dependency order.
run_install() {
    local -n features=$1
    
    if [[ ${#features[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_task "Installing features..."
    
    for feature in "${features[@]}"; do
        local install_script="$DOTFILES_FEATURES_DIR/$feature/install.sh"
        
        if [[ ! -f "$install_script" ]]; then
            log_error "Install script not found: $install_script"
            return 1
        fi
        
        # Extract feature config and pass via environment variable
        local feature_config=$(extract_feature_config "$feature")
        local feature_version=$(echo "$feature_config" | jq -r '.version // empty')
        
        log_info "Installing: $feature"
        
        # Export config for install script to use
        export DOTFILES_FEATURE_CONFIG_VERSION="$feature_version"
        
        if ! bash "$install_script"; then
            log_error "Failed to install: $feature"
            return 1
        fi
        
        # Clear env var after install
        unset DOTFILES_FEATURE_CONFIG_VERSION
    done
    
    return 0
}

# print_summary
# Display summary of successfully installed features.
print_summary() {
    echo ""
    log_success "Profile applied successfully!"
    echo ""
    echo "Installed features:"
    for feature in $(state_list_features); do
        echo "  ✓ $feature"
    done
    echo ""
}
