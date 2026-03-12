#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: compiler (FeatureCompiler)
#
# Responsibility:
#   Compile the DesiredResourceGraph from Feature Index + resolved feature order
#   and policy (desired_backend resolution).
#
# Public API (Stable):
#   feature_compiler_run <feature_index_json> <sorted_features_nameref>
#   Prints DesiredResourceGraph JSON to stdout.
#
# Contract:
#   - mode:script  → entry with empty resources array (no script execution here)
#   - mode:declarative → resources expanded with desired_backend from policy
#   - Declarative validation: error if no resources, error if install.sh present
#   - Planner must not re-resolve backends; desired_backend is authoritative here
#
# JSON schema: see docs/specs/data/desired_resource_graph.md
# -----------------------------------------------------------------------------

# This library expects env.sh, logger.sh, source_registry.sh, and
# backend_registry.sh to be sourced by the caller.

# Lazily source backend_registry if not already loaded
if [[ "$(type -t resolve_backend_for)" != "function" ]]; then
    # shellcheck source=core/lib/backend_registry.sh
    source "${DOTFILES_ROOT}/core/lib/backend_registry.sh"
fi

# _compiler_resource_id <kind> <resource_json>
# Derive a stable resource id from a resource JSON object.
# Uses .id if present; otherwise auto-generates from kind+name/path.
_compiler_resource_id() {
    local kind="$1"
    local resource_json="$2"

    local existing_id
    existing_id=$(printf '%s' "$resource_json" | jq -r '.id // empty')
    if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
        echo "$existing_id"
        return 0
    fi

    case "$kind" in
        package)
            local name
            name=$(printf '%s' "$resource_json" | jq -r '.name // empty')
            echo "package:${name}"
            ;;
        runtime)
            local name
            name=$(printf '%s' "$resource_json" | jq -r '.name // empty')
            echo "runtime:${name}"
            ;;
        fs)
            local path
            path=$(printf '%s' "$resource_json" | jq -r '.path // empty')
            echo "fs:$(basename "$path")"
            ;;
        *)
            echo "${kind}:unknown"
            ;;
    esac
}

# _compiler_resolve_resource <canonical_id> <resource_json>
# Add desired_backend and id to a resource JSON object.
# Prints updated resource JSON to stdout.
_compiler_resolve_resource() {
    local canonical_id="$1"
    local resource_json="$2"

    local kind
    kind=$(printf '%s' "$resource_json" | jq -r '.kind // empty')
    if [[ -z "$kind" || "$kind" == "null" ]]; then
        log_error "feature_compiler_run: resource missing 'kind' in $canonical_id"
        return 1
    fi

    local resource_id
    resource_id=$(_compiler_resource_id "$kind" "$resource_json") || return 1

    # Resolve desired_backend (only for package and runtime; fs has no backend)
    local updated_json
    case "$kind" in
        package)
            local name desired_backend
            name=$(printf '%s' "$resource_json" | jq -r '.name // empty')
            desired_backend=$(resolve_backend_for "package" "$name" 2>/dev/null) || desired_backend="unknown"
            updated_json=$(printf '%s' "$resource_json" | jq \
                --arg id      "$resource_id" \
                --arg backend "$desired_backend" \
                '. + {"id": $id, "desired_backend": $backend}')
            ;;
        runtime)
            local name desired_backend
            name=$(printf '%s' "$resource_json" | jq -r '.name // empty')
            desired_backend=$(resolve_backend_for "runtime" "$name" 2>/dev/null) || desired_backend="unknown"
            updated_json=$(printf '%s' "$resource_json" | jq \
                --arg id      "$resource_id" \
                --arg backend "$desired_backend" \
                '. + {"id": $id, "desired_backend": $backend}')
            ;;
        fs)
            # fs resources have no backend
            updated_json=$(printf '%s' "$resource_json" | jq \
                --arg id "$resource_id" \
                '. + {"id": $id}')
            ;;
        *)
            log_error "feature_compiler_run: unknown resource kind '$kind' in $canonical_id"
            return 1
            ;;
    esac

    printf '%s' "$updated_json"
}

# feature_compiler_run <feature_index_json> <sorted_features_nameref>
# Compile DesiredResourceGraph from Feature Index and resolved feature order.
# Prints DesiredResourceGraph JSON to stdout.
#
# For mode:script features: produces an entry with an empty resources array.
# For mode:declarative features: expands resources with desired_backend.
feature_compiler_run() {
    local feature_index_json="$1"
    local -n _fcr_sorted="$2"

    local features_json="{}"

    local canonical_id
    for canonical_id in "${_fcr_sorted[@]}"; do
        local entry
        entry=$(printf '%s' "$feature_index_json" \
            | jq -r --arg id "$canonical_id" '.features[$id] // "null"')

        if [[ "$entry" == "null" ]]; then
            log_error "feature_compiler_run: feature not found in index: $canonical_id"
            return 1
        fi

        local mode
        mode=$(printf '%s' "$entry" | jq -r '.mode')

        local resources_json="[]"

        if [[ "$mode" == "declarative" ]]; then
            # ── Declarative validation ─────────────────────────────────────
            local source_dir
            source_dir=$(printf '%s' "$entry" | jq -r '.source_dir')

            # Must not have install.sh or uninstall.sh
            if [[ -f "$source_dir/install.sh" || -f "$source_dir/uninstall.sh" ]]; then
                log_error "feature_compiler_run: declarative feature must not have install.sh/uninstall.sh: $canonical_id"
                return 1
            fi

            # spec must exist with at least one resource
            local spec_resources
            spec_resources=$(printf '%s' "$entry" | jq '.spec.resources // []')
            local res_count
            res_count=$(printf '%s' "$spec_resources" | jq 'length')
            if [[ "$res_count" -eq 0 ]]; then
                log_error "feature_compiler_run: declarative feature has no resources defined: $canonical_id"
                return 1
            fi

            # ── Expand resources with desired_backend ──────────────────────
            while IFS= read -r resource_json; do
                local resolved
                resolved=$(_compiler_resolve_resource "$canonical_id" "$resource_json") || return 1
                resources_json=$(printf '%s' "$resources_json" \
                    | jq --argjson r "$resolved" '. + [$r]')
            done < <(printf '%s' "$spec_resources" | jq -c '.[]')
        fi

        features_json=$(printf '%s' "$features_json" | jq \
            --arg id  "$canonical_id" \
            --argjson res "$resources_json" \
            '.[$id] = {"resources": $res}')
    done

    printf '{"schema_version": 1, "features": %s}\n' "$features_json"
}
