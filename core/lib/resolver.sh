#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: resolver
#
# Responsibility:
#   Resolve feature dependencies and perform topological sorting.
#
# Public API (Stable):
#   resolve_dependencies <desired_features> <output_array>
#   read_feature_metadata <features>
# -----------------------------------------------------------------------------

# This library expects core/env.sh and core/lib/logger.sh to be sourced by the caller.

# Global variables for dependency graph
declare -g -A _RESOLVER_FEATURE_DEPS
declare -g -A _RESOLVER_VISITED
declare -g -A _RESOLVER_IN_STACK
declare -g -a _RESOLVER_SORTED

# read_feature_metadata <features>
# Read dependency metadata from meta.yaml files for all features.
read_feature_metadata() {
    local -n features=$1
    
    _RESOLVER_FEATURE_DEPS=()
    
    log_info "Reading feature metadata..."
    for feature in "${features[@]}"; do
        local meta_file="$DOTFILES_FEATURES_DIR/$feature/meta.yaml"
        local platform_meta_file="$DOTFILES_FEATURES_DIR/$feature/meta.${DOTFILES_PLATFORM}.yaml"
        
        if [[ ! -f "$meta_file" ]]; then
            log_error "Meta file not found: $meta_file"
            return 1
        fi
        
        # Read common dependencies
        local deps=($(yq eval '.depends[]' "$meta_file" 2>/dev/null || true))
        
        # Read platform-specific dependencies if exists
        if [[ -f "$platform_meta_file" ]]; then
            local platform_deps=($(yq eval '.depends[]' "$platform_meta_file" 2>/dev/null || true))
            deps+=("${platform_deps[@]}")
        fi
        
        # Store unique dependencies
        local unique_deps=($(printf '%s\n' "${deps[@]}" | sort -u))
        _RESOLVER_FEATURE_DEPS["$feature"]="${unique_deps[*]}"
        
        if [[ ${#unique_deps[@]} -gt 0 ]]; then
            log_info "  $feature depends on: ${unique_deps[*]}"
        else
            log_info "  $feature has no dependencies"
        fi
    done
}

# Depth-first search for topological sort
_topo_sort_dfs() {
    local feature="$1"
    shift
    local desired_features=("$@")
    
    # Check if already visited
    if [[ "${_RESOLVER_VISITED[$feature]:-}" == "true" ]]; then
        return 0
    fi
    
    # Check for cycle
    if [[ "${_RESOLVER_IN_STACK[$feature]:-}" == "true" ]]; then
        log_error "Circular dependency detected involving: $feature"
        return 1
    fi
    
    _RESOLVER_IN_STACK["$feature"]="true"
    
    # Visit dependencies first
    local deps=(${_RESOLVER_FEATURE_DEPS[$feature]})
    for dep in "${deps[@]}"; do
        # Check if dependency is in desired features
        if [[ ! " ${desired_features[*]} " =~ " ${dep} " ]]; then
            log_error "Dependency '$dep' (required by '$feature') is not in profile"
            return 1
        fi
        
        _topo_sort_dfs "$dep" "${desired_features[@]}" || return 1
    done
    
    _RESOLVER_IN_STACK["$feature"]="false"
    _RESOLVER_VISITED["$feature"]="true"
    _RESOLVER_SORTED+=("$feature")
}

# resolve_dependencies <desired_features> <output_array>
# Resolve dependencies and return topologically sorted feature list.
resolve_dependencies() {
    local -n desired_features=$1
    local -n output_array=$2
    
    _RESOLVER_VISITED=()
    _RESOLVER_IN_STACK=()
    _RESOLVER_SORTED=()
    
    log_info "Resolving dependencies..."
    
    # Sort all features
    for feature in "${desired_features[@]}"; do
        _topo_sort_dfs "$feature" "${desired_features[@]}" || return 1
    done
    
    # Copy result to output array
    output_array=("${_RESOLVER_SORTED[@]}")
    
    log_success "Install order: ${output_array[*]}"
    return 0
}
