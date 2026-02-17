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

# read_profile <profile_file> <output_array>
# Read profile YAML file and extract feature list.
read_profile() {
    local profile_file="$1"
    local -n output_array=$2
    
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: $profile_file"
        return 1
    fi
    
    log_info "Reading profile..."
    output_array=($(yq eval '.features[]' "$profile_file"))
    
    if [[ ${#output_array[@]} -eq 0 ]]; then
        log_warn "Empty profile (no features specified)"
        log_info "All installed features will be uninstalled"
        return 0
    fi
    
    log_info "Desired features: ${output_array[*]}"
    return 0
}

# calculate_diff <sorted_features> <to_install> <to_uninstall>
# Calculate difference between desired and installed features.
calculate_diff() {
    local -n sorted_features=$1
    local -n to_install=$2
    local -n to_uninstall=$3
    
    local installed_features=($(state_list_features))
    
    to_install=()
    to_uninstall=()
    
    # Find features to install
    for feature in "${sorted_features[@]}"; do
        if ! state_has_feature "$feature"; then
            to_install+=("$feature")
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
        
        log_info "Installing: $feature"
        if ! bash "$install_script"; then
            log_error "Failed to install: $feature"
            return 1
        fi
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
