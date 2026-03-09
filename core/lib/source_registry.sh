#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: source_registry
#
# Responsibility:
#   Canonical ID utilities for feature and backend identification.
#   A canonical ID is a string of the form "<source_id>/<name>".
#
#   This module provides Phase 1 foundations only.
#   Source loading (sources.yaml, allow lists) is Phase 5.
#
# Reserved source IDs (may not be defined in sources.yaml):
#   core     — built-in features shipped with this repository
#   user     — local user overrides
#   official — reserved for future use
#
# Public API (Stable):
#   canonical_id_normalize <name> <default_source_id>
#   canonical_id_parse     <canonical_id> <out_source_var> <out_name_var>
#   canonical_id_validate  <canonical_id>
# -----------------------------------------------------------------------------

# List of source IDs that cannot be defined by the user in sources.yaml.
# Used for validation in Phase 5; exposed here as a single source of truth.
readonly CANONICAL_ID_RESERVED_SOURCES="core user official"

# canonical_id_normalize <name> <default_source_id>
#
# Normalize a feature/backend name to a canonical ID.
# If <name> is already a canonical ID ("source/name"), it is returned as-is.
# If <name> is a bare name, <default_source_id>/<name> is produced.
#
# Outputs the canonical ID to stdout.
# Returns 1 if the resulting canonical ID would be invalid.
#
# Examples:
#   canonical_id_normalize "git"         "core"   -> "core/git"
#   canonical_id_normalize "user/myfeat" "core"   -> "user/myfeat"
#   canonical_id_normalize "repo-a/foo"  "core"   -> "repo-a/foo"
canonical_id_normalize() {
    local name="$1"
    local default_source="$2"

    if [[ -z "$name" ]]; then
        log_error "canonical_id_normalize: name is required"
        return 1
    fi
    if [[ -z "$default_source" ]]; then
        log_error "canonical_id_normalize: default_source_id is required"
        return 1
    fi

    local result
    # Already contains a slash → treat as canonical; validate before returning
    if [[ "$name" == */* ]]; then
        result="$name"
    else
        # Bare name → prepend default source
        result="${default_source}/${name}"
    fi

    if ! canonical_id_validate "$result"; then
        return 1
    fi

    echo "$result"
}

# canonical_id_parse <canonical_id> <out_source_var> <out_name_var>
#
# Parse a canonical ID into its source_id and name components.
# Writes results to the caller-supplied variable names (nameref).
# Returns 1 if <canonical_id> is not a valid canonical ID.
#
# Example:
#   local src name
#   canonical_id_parse "core/git" src name
#   # src="core", name="git"
canonical_id_parse() {
    local canonical_id="$1"
    local -n _cip_source_out=$2
    local -n _cip_name_out=$3

    if ! canonical_id_validate "$canonical_id"; then
        return 1
    fi

    _cip_source_out="${canonical_id%%/*}"
    _cip_name_out="${canonical_id#*/}"
}

# canonical_id_validate <canonical_id>
#
# Validate that <canonical_id> is a well-formed canonical ID.
# A valid canonical ID:
#   - is non-empty
#   - contains exactly one "/" separator
#   - has a non-empty source_id part (left of "/")
#   - has a non-empty name part (right of "/")
#   - neither part contains a "/"
#
# Returns 0 if valid, 1 if invalid.
# Does NOT check whether the source_id is reserved — that is source_registry_load's job.
canonical_id_validate() {
    local id="$1"

    # Must be non-empty
    if [[ -z "$id" ]]; then
        return 1
    fi

    # Must contain exactly one "/"
    local slash_count
    slash_count=$(echo "$id" | tr -cd '/' | wc -c)
    if [[ "$slash_count" -ne 1 ]]; then
        return 1
    fi

    local source_part="${id%%/*}"
    local name_part="${id#*/}"

    # Both parts must be non-empty
    if [[ -z "$source_part" ]] || [[ -z "$name_part" ]]; then
        return 1
    fi

    return 0
}
