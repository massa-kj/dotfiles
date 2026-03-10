#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: resolver
#
# Responsibility:
#   Resolve feature dependencies and perform topological sorting.
#   Supports capability-based dependencies via requires/provides fields.
#
# Public API (Stable):
#   resolve_dependencies <desired_features> <output_array>
#   read_feature_metadata <features>
#
# Input/output format (Phase 2+):
#   All feature identifiers are canonical IDs of the form "<source_id>/<name>".
#   Bare names in profile are normalized upstream (orchestrator.read_profile).
#   Bare names in meta.yaml depends[] are normalized here using the feature's own
#   source_id as the default (same-source dependency rule).
# -----------------------------------------------------------------------------

# This library expects core/env.sh, core/lib/logger.sh, and
# core/lib/source_registry.sh to be sourced by the caller.

# Lazily source source_registry if not already loaded
if [[ "$(type -t canonical_id_normalize)" != "function" ]]; then
    # shellcheck source=core/lib/source_registry.sh
    source "${DOTFILES_ROOT}/core/lib/source_registry.sh"
fi

# Global variables for dependency graph
declare -g -A _RESOLVER_FEATURE_DEPS  # feature -> "dep1 dep2 ..."
declare -g -A _RESOLVER_VISITED
declare -g -A _RESOLVER_IN_STACK
declare -g -a _RESOLVER_SORTED

# Capability maps built by read_feature_metadata
declare -g -A _RESOLVER_PROVIDES  # capability -> "feature1 feature2 ..."
declare -g -A _RESOLVER_REQUIRES  # feature -> "cap1 cap2 ..."

# _resolver_platform_meta_file <feature>
# Print the path to the platform-specific meta file, or empty string if none.
# <feature> may be a canonical ID ("core/git") or a bare name; both are handled.
_resolver_platform_meta_file() {
    local feature="$1"
    local feat_name="${feature#*/}"  # "core/git" -> "git", "git" -> "git"
    if [[ "$DOTFILES_PLATFORM" == "wsl" ]]; then
        if [[ -f "$DOTFILES_FEATURES_DIR/$feat_name/meta.wsl.yaml" ]]; then
            echo "$DOTFILES_FEATURES_DIR/$feat_name/meta.wsl.yaml"
        elif [[ -f "$DOTFILES_FEATURES_DIR/$feat_name/meta.linux.yaml" ]]; then
            echo "$DOTFILES_FEATURES_DIR/$feat_name/meta.linux.yaml"
        fi
    elif [[ "$DOTFILES_PLATFORM" == "linux" ]]; then
        if [[ -f "$DOTFILES_FEATURES_DIR/$feat_name/meta.linux.yaml" ]]; then
            echo "$DOTFILES_FEATURES_DIR/$feat_name/meta.linux.yaml"
        fi
    else
        if [[ -f "$DOTFILES_FEATURES_DIR/$feat_name/meta.${DOTFILES_PLATFORM}.yaml" ]]; then
            echo "$DOTFILES_FEATURES_DIR/$feat_name/meta.${DOTFILES_PLATFORM}.yaml"
        fi
    fi
}

# read_feature_metadata <features>
# Read dependency metadata from meta.yaml files for all features.
# <features> must contain canonical IDs (e.g. "core/git", "user/myfeat").
# Bare names in meta.yaml depends[] are normalized to same-source canonical IDs.
#
# Populates:
#   _RESOLVER_FEATURE_DEPS  – canonical depends per feature
#   _RESOLVER_PROVIDES      – capability -> canonical features that provide it
#   _RESOLVER_REQUIRES      – canonical feature -> required capabilities
read_feature_metadata() {
    local -n features=$1

    _RESOLVER_FEATURE_DEPS=()
    _RESOLVER_PROVIDES=()
    _RESOLVER_REQUIRES=()

    log_info "Reading feature metadata..."
    for feature in "${features[@]}"; do
        # Extract name part for file path: "core/git" -> "git"
        local feat_name="${feature#*/}"
        local source_id="${feature%%/*}"
        local meta_file="$DOTFILES_FEATURES_DIR/$feat_name/meta.yaml"

        if [[ ! -f "$meta_file" ]]; then
            log_error "Meta file not found: $meta_file (feature: $feature)"
            return 1
        fi

        local platform_meta_file
        platform_meta_file=$(_resolver_platform_meta_file "$feature")

        # ── depends ─────────────────────────────────────────────────────────
        local raw_deps
        mapfile -t raw_deps < <(yq eval '.depends[]' "$meta_file" 2>/dev/null || true)

        if [[ -n "$platform_meta_file" ]]; then
            local platform_deps
            mapfile -t platform_deps < <(yq eval '.depends[]' "$platform_meta_file" 2>/dev/null || true)
            raw_deps+=("${platform_deps[@]}")
        fi

        # Normalize each dep to a canonical ID using this feature's source_id as default.
        # Bare dep names are treated as same-source ("core/mise" for a dep "mise" in "core/neovim").
        # Explicit canonical IDs ("user/foo") are passed through unchanged.
        local canonical_deps=()
        local dep canonical_dep
        for dep in "${raw_deps[@]}"; do
            [[ -z "$dep" ]] && continue
            canonical_dep=$(canonical_id_normalize "$dep" "$source_id") || {
                log_error "read_feature_metadata: invalid depends entry '$dep' in $feature"
                return 1
            }
            canonical_deps+=("$canonical_dep")
        done

        # Deduplicate
        local unique_deps
        mapfile -t unique_deps < <(printf '%s\n' "${canonical_deps[@]}" | sort -u | grep -v '^$')
        _RESOLVER_FEATURE_DEPS["$feature"]="${unique_deps[*]}"

        # ── provides ────────────────────────────────────────────────────────
        local provides
        mapfile -t provides < <(yq eval '.provides[].name' "$meta_file" 2>/dev/null || true)

        if [[ -n "$platform_meta_file" ]]; then
            local platform_provides
            mapfile -t platform_provides < <(yq eval '.provides[].name' "$platform_meta_file" 2>/dev/null || true)
            provides+=("${platform_provides[@]}")
        fi

        for cap in "${provides[@]}"; do
            [[ -z "$cap" ]] && continue
            if [[ -n "${_RESOLVER_PROVIDES[$cap]:-}" ]]; then
                _RESOLVER_PROVIDES["$cap"]+=" $feature"
            else
                _RESOLVER_PROVIDES["$cap"]="$feature"
            fi
        done

        # ── requires ────────────────────────────────────────────────────────
        local requires
        mapfile -t requires < <(yq eval '.requires[].name' "$meta_file" 2>/dev/null || true)

        if [[ -n "$platform_meta_file" ]]; then
            local platform_requires
            mapfile -t platform_requires < <(yq eval '.requires[].name' "$platform_meta_file" 2>/dev/null || true)
            requires+=("${platform_requires[@]}")
        fi

        local unique_requires
        mapfile -t unique_requires < <(printf '%s\n' "${requires[@]}" | sort -u | grep -v '^$')
        _RESOLVER_REQUIRES["$feature"]="${unique_requires[*]}"

        # ── log ─────────────────────────────────────────────────────────────
        if [[ ${#unique_deps[@]} -gt 0 ]]; then
            log_info "  $feature depends on: ${unique_deps[*]}"
        fi
        if [[ ${#provides[@]} -gt 0 ]]; then
            log_info "  $feature provides: ${provides[*]}"
        fi
        if [[ ${#unique_requires[@]} -gt 0 ]]; then
            log_info "  $feature requires capabilities: ${unique_requires[*]}"
        fi
        if [[ ${#unique_deps[@]} -eq 0 && ${#provides[@]} -eq 0 && ${#unique_requires[@]} -eq 0 ]]; then
            log_info "  $feature has no dependencies"
        fi
    done
}

# _resolver_inject_capability_deps <desired_features_nameref>
# For each feature with requires[], find providers in the desired features and
# inject them as implicit entries in _RESOLVER_FEATURE_DEPS.
# Errors if a required capability has no provider in the profile.
_resolver_inject_capability_deps() {
    local -n _inject_desired=$1

    for feature in "${_inject_desired[@]}"; do
        local caps=(${_RESOLVER_REQUIRES[$feature]:-})
        [[ ${#caps[@]} -eq 0 ]] && continue

        for cap in "${caps[@]}"; do
            # Find providers that are present in the desired feature set
            local all_providers=(${_RESOLVER_PROVIDES[$cap]:-})
            local found_providers=()

            for p in "${all_providers[@]}"; do
                if [[ " ${_inject_desired[*]} " =~ " ${p} " ]]; then
                    found_providers+=("$p")
                fi
            done

            if [[ ${#found_providers[@]} -eq 0 ]]; then
                log_error "Feature '$feature' requires capability '$cap'" \
                    "but no provider is present in the profile."
                log_error "  Known providers: ${all_providers[*]:-(none registered)}"
                return 1
            fi

            # Add each found provider as an implicit dependency (deduplicate)
            for p in "${found_providers[@]}"; do
                local existing="${_RESOLVER_FEATURE_DEPS[$feature]:-}"
                if [[ ! " $existing " =~ " $p " ]]; then
                    _RESOLVER_FEATURE_DEPS["$feature"]+="${existing:+ }$p"
                fi
            done

            log_info "  $feature: capability '$cap' provided by: ${found_providers[*]}"
        done
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

    # Visit dependencies first (includes capability-injected implicit deps)
    local deps=(${_RESOLVER_FEATURE_DEPS[$feature]:-})
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
# Resolve capability dependencies and return topologically sorted feature list.
resolve_dependencies() {
    local -n desired_features=$1
    local -n output_array=$2

    _RESOLVER_VISITED=()
    _RESOLVER_IN_STACK=()
    _RESOLVER_SORTED=()

    log_info "Resolving dependencies..."

    # Inject implicit deps derived from requires/provides into _RESOLVER_FEATURE_DEPS
    _resolver_inject_capability_deps desired_features || return 1

    # Sort all features
    for feature in "${desired_features[@]}"; do
        _topo_sort_dfs "$feature" "${desired_features[@]}" || return 1
    done

    # Copy result to output array
    output_array=("${_RESOLVER_SORTED[@]}")

    log_success "Install order (canonical IDs): ${output_array[*]}"
    return 0
}
