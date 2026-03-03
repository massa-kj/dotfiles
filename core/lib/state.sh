#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: state
#
# Responsibility:
#   Manage state file (v2) with atomic writes, migration, and patch operations.
#
# Stable Public API:
#   state_load
#   state_validate <mode>                     mode = load | execute
#   state_commit_atomic <json>
#   state_query_feature <feature>
#   state_query_resources <feature>
#   state_patch_begin
#   state_patch_add_resource <feature> <resource_json>
#   state_patch_remove_feature <feature>
#   state_patch_finalize
#   state_migrate
#
# Compat API (updated Phase 4):
#   state_init                                — keep (used by scripts)
#   state_has_feature <feature>               — keep
#   state_list_features                       — keep
#   state_get_packages <feature>              — keep (node/python uninstall)
#   state_get_files <feature>                 — keep
#   state_has_file <path>                     — keep
#   state_add_package <feature> <package>     — keep (npm:/uv: secondary packages)
#   state_add_file <feature> <path>           — keep (git gitconfig complex merge)
#   state_get_runtime <feature> <key>         — keep (read-only)
#   state_has_runtime <feature> <key>         — keep (read-only)
#   state_remove_feature <feature>            — DEPRECATED; executor uses state_patch_remove_feature
#   state_set_runtime <feature> <key> <value> — DEPRECATED; executor writes runtime resources
# -----------------------------------------------------------------------------

# ── Private state ─────────────────────────────────────────────────────────────

# In-memory cache of the authoritative state (JSON string).
declare -g _STATE_JSON=""

# Working copy for patch operations.
declare -g _STATE_PATCH_JSON=""

# ── Internal helpers ──────────────────────────────────────────────────────────

# _state_ensure_loaded
# Guard: run state_load if cache is empty.
_state_ensure_loaded() {
    if [[ -z "$_STATE_JSON" ]]; then
        state_load || return 1
    fi
}

# ── Stable Core API ───────────────────────────────────────────────────────────

# state_load
# Load state from disk into in-memory cache.
# If v1 is detected, migrate automatically and commit.
# Creates empty v2 state if the file does not exist.
state_load() {
    if [[ -z "${DOTFILES_STATE_FILE:-}" ]]; then
        log_error "state_load: DOTFILES_STATE_FILE is not set"
        return 1
    fi

    local path="$DOTFILES_STATE_FILE"
    local dir
    dir="$(dirname "$path")"

    # Create state directory if missing
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi

    # Create empty v2 state if file does not exist
    if [[ ! -f "$path" ]]; then
        _STATE_JSON='{"version":2,"features":{}}'
        echo "$_STATE_JSON" > "$path"
        return 0
    fi

    # Validate JSON parsability
    if ! jq empty "$path" 2>/dev/null; then
        log_error "state_load: state file is not valid JSON: $path"
        return 1
    fi

    _STATE_JSON="$(cat "$path")"

    # Auto-migrate v1 → v2
    local ver
    ver=$(echo "$_STATE_JSON" | jq -r '.version // empty')

    if [[ "$ver" == "1" ]]; then
        log_info "state_load: v1 state detected, migrating to v2..."
        if ! state_migrate; then
            log_error "state_load: migration failed"
            return 1
        fi
    elif [[ "$ver" != "2" ]]; then
        log_error "state_load: unknown state version: ${ver:-<missing>}"
        return 1
    fi

    return 0
}

# state_validate <mode> [json]
# Validate structural invariants.
#   mode=load    – allow unknown resource kinds; check structural sanity.
#   mode=execute – additionally abort on features containing unknown kinds.
# If [json] is omitted, the in-memory cache is validated.
state_validate() {
    local mode="${1:-load}"
    local json="${2:-$_STATE_JSON}"

    if [[ -z "$json" ]]; then
        log_error "state_validate: no state loaded"
        return 1
    fi

    # 1. JSON validity
    if ! echo "$json" | jq empty 2>/dev/null; then
        log_error "state_validate: invalid JSON"
        return 1
    fi

    # 2. version MUST be 2
    local ver
    ver=$(echo "$json" | jq -r '.version')
    if [[ "$ver" != "2" ]]; then
        log_error "state_validate: version MUST be 2, got: $ver"
        return 1
    fi

    # 3. features MUST be an object
    if ! echo "$json" | jq -e '.features | type == "object"' >/dev/null 2>&1; then
        log_error "state_validate: .features must be an object"
        return 1
    fi

    # 4. Each feature MUST have a resources array; each resource MUST have kind and id
    local missing
    missing=$(echo "$json" | jq -r '
      .features | to_entries[] |
      . as $f |
      if (.value.resources | type) != "array" then
        "feature \(.key): resources must be an array"
      else
        (.value.resources[] |
          if (.kind == null or .kind == "") or (.id == null or .id == "") then
            "feature \($f.key): resource missing kind or id"
          else empty end)
      end
    ' 2>/dev/null)
    if [[ -n "$missing" ]]; then
        log_error "state_validate: $missing"
        return 1
    fi

    # 5. Within a feature: no duplicate resource.id
    local dup_res
    dup_res=$(echo "$json" | jq -r '
      .features | to_entries[] |
      . as $f |
      (.value.resources | map(.id) | group_by(.) | map(select(length > 1)) | .[]) |
      "feature \($f.key): duplicate resource id: \(.[0])"
    ' 2>/dev/null)
    if [[ -n "$dup_res" ]]; then
        log_error "state_validate: $dup_res"
        return 1
    fi

    # 6. Across all features: no duplicate fs.path
    local dup_path
    dup_path=$(echo "$json" | jq -r '
      [.features | to_entries[] | .value.resources[] |
        select(.kind == "fs") | .fs.path] |
      group_by(.) | map(select(length > 1)) | .[] | .[0] |
      "duplicate fs.path across features: \(.)"
    ' 2>/dev/null)
    if [[ -n "$dup_path" ]]; then
        log_error "state_validate: $dup_path"
        return 1
    fi

    # 7. All fs.path MUST be absolute
    local nonabs
    nonabs=$(echo "$json" | jq -r '
      .features | to_entries[] | .value.resources[] |
      select(.kind == "fs" and (.fs.path | startswith("/") | not)) |
      "fs.path not absolute: \(.fs.path)"
    ' 2>/dev/null)
    if [[ -n "$nonabs" ]]; then
        log_error "state_validate: $nonabs"
        return 1
    fi

    # mode=execute: abort on features containing unknown kinds
    if [[ "$mode" == "execute" ]]; then
        local unknown
        unknown=$(echo "$json" | jq -r '
          .features | to_entries[] |
          . as $f |
          (.value.resources // [])[] |
          select([.kind] | inside(["package","runtime","fs"]) | not) |
          "feature \($f.key): unknown kind: \(.kind)"
        ' 2>/dev/null)
        if [[ -n "$unknown" ]]; then
            log_error "state_validate(execute): $unknown"
            return 1
        fi
    fi

    return 0
}

# state_commit_atomic <json>
# Write a new state atomically: write to .tmp → validate → atomic rename.
state_commit_atomic() {
    local new_json="$1"

    if [[ -z "${DOTFILES_STATE_FILE:-}" ]]; then
        log_error "state_commit_atomic: DOTFILES_STATE_FILE is not set"
        return 1
    fi

    local path="$DOTFILES_STATE_FILE"
    local tmp="${path}.tmp"

    if [[ -z "$new_json" ]]; then
        log_error "state_commit_atomic: empty JSON provided"
        return 1
    fi

    # Write to tmp (pretty-print for readability)
    if ! echo "$new_json" | jq '.' > "$tmp" 2>/dev/null; then
        log_error "state_commit_atomic: failed to write tmp file"
        rm -f "$tmp"
        return 1
    fi

    # Validate before committing
    local tmp_content
    tmp_content="$(cat "$tmp")"
    if ! state_validate "load" "$tmp_content"; then
        log_error "state_commit_atomic: validation failed, aborting commit"
        rm -f "$tmp"
        return 1
    fi

    # Atomic rename
    if ! mv "$tmp" "$path"; then
        log_error "state_commit_atomic: atomic rename failed"
        rm -f "$tmp"
        return 1
    fi

    # Update in-memory cache
    _STATE_JSON="$tmp_content"

    return 0
}

# state_query_feature <feature>
# Output the feature entry JSON (compact), or nothing if not found.
state_query_feature() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_query_feature: feature name is required"
        return 1
    fi
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -c --arg f "$feature" '.features[$f] // empty'
}

# state_query_resources <feature>
# Output the resources array JSON for a feature, or [] if not found.
state_query_resources() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_query_resources: feature name is required"
        return 1
    fi
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -c --arg f "$feature" '.features[$f].resources // []'
}

# ── Patch Operations ──────────────────────────────────────────────────────────

# state_patch_begin
# Initialize a patch working copy from the current state cache.
state_patch_begin() {
    _state_ensure_loaded || return 1
    _STATE_PATCH_JSON="$_STATE_JSON"
}

# state_patch_add_resource <feature> <resource_json>
# Add (or replace by id) a resource in the patch working copy.
# Creates the feature entry if it does not exist.
state_patch_add_resource() {
    local feature="$1"
    local resource_json="$2"

    if [[ -z "$feature" ]] || [[ -z "$resource_json" ]]; then
        log_error "state_patch_add_resource: feature and resource_json are required"
        return 1
    fi

    if [[ -z "$_STATE_PATCH_JSON" ]]; then
        log_error "state_patch_add_resource: no patch in progress; call state_patch_begin first"
        return 1
    fi

    _STATE_PATCH_JSON=$(echo "$_STATE_PATCH_JSON" | jq \
        --arg f "$feature" \
        --argjson res "$resource_json" '
        if .features[$f] == null then
            .features[$f] = {"resources": []}
        else . end |
        .features[$f].resources = (
            [.features[$f].resources[] | select(.id != $res.id)] + [$res]
        )
    ')
}

# state_patch_remove_feature <feature>
# Remove a feature entry from the patch working copy.
state_patch_remove_feature() {
    local feature="$1"

    if [[ -z "$feature" ]]; then
        log_error "state_patch_remove_feature: feature name is required"
        return 1
    fi

    if [[ -z "$_STATE_PATCH_JSON" ]]; then
        log_error "state_patch_remove_feature: no patch in progress; call state_patch_begin first"
        return 1
    fi

    _STATE_PATCH_JSON=$(echo "$_STATE_PATCH_JSON" | jq --arg f "$feature" 'del(.features[$f])')
}

# state_patch_finalize
# Commit the patch working copy atomically and clear the buffer.
state_patch_finalize() {
    if [[ -z "$_STATE_PATCH_JSON" ]]; then
        log_error "state_patch_finalize: no patch in progress"
        return 1
    fi

    if ! state_commit_atomic "$_STATE_PATCH_JSON"; then
        _STATE_PATCH_JSON=""
        return 1
    fi

    _STATE_PATCH_JSON=""
    return 0
}

# ── Migration ─────────────────────────────────────────────────────────────────

# state_migrate
# Migrate the in-memory v1 state to v2: backup → transform → commit atomically.
# Called automatically by state_load; may also be called via `dotfiles migrate-state`.
state_migrate() {
    local path="$DOTFILES_STATE_FILE"
    local backup="${path}.bak"

    # Backup current file
    if [[ -f "$path" ]]; then
        cp "$path" "$backup" || {
            log_error "state_migrate: failed to create backup at $backup"
            return 1
        }
        log_info "state_migrate: backup created: $backup"
    fi

    # Transform
    local v2_json
    if ! v2_json=$(_migrate_v1_to_v2 "$_STATE_JSON"); then
        log_error "state_migrate: transformation failed; restore from: $backup"
        return 1
    fi

    # Commit atomically
    if ! state_commit_atomic "$v2_json"; then
        log_error "state_migrate: commit failed; restore from: $backup"
        return 1
    fi

    log_info "state_migrate: migration to v2 complete"
    return 0
}

# _migrate_v1_to_v2 <v1_json>
# Pure transformation: convert v1 schema to v2 resources format.
# Outputs v2 JSON to stdout.
#
# v1 → v2 mapping:
#   packages[]          → kind:package resources
#   files[]             → kind:fs resources  (entry_type/op inferred from filesystem)
#   runtime.version     → kind:runtime resource (runtime name = feature_id)
#   "{fid}@{rv}" entry  → skipped when runtime.version is set (captured by runtime resource)
_migrate_v1_to_v2() {
    local v1_json="$1"

    # ── Structural transformation (jq) ──────────────────────────────────────
    local intermediate
    intermediate=$(echo "$v1_json" | jq '
      {
        version: 2,
        features: (
          .features | to_entries | map(
            .key as $fid |
            (.value.runtime.version // null) as $rv |
            {
              key: $fid,
              value: {
                resources: (
                  # ── package resources ─────────────────────────────────────
                  # Skip entries matching "{feature_id}@{runtime_version}"
                  # because those are captured as kind:runtime below.
                  [
                    (.value.packages // [])[] |
                    . as $pkg |
                    if ($rv != null and $pkg == ($fid + "@" + $rv))
                    then empty
                    else {
                      kind: "package",
                      id: ("pkg:" + $pkg),
                      backend: "unknown",
                      package: { name: $pkg, version: null }
                    }
                    end
                  ] +

                  # ── fs resources ──────────────────────────────────────────
                  [
                    (.value.files // [])[] |
                    {
                      kind: "fs",
                      id: ("fs:" + .),
                      fs: {
                        path: .,
                        entry_type: "file",
                        op: "copy"
                      }
                    }
                  ] +

                  # ── runtime resource ──────────────────────────────────────
                  if $rv != null
                  then [{
                    kind: "runtime",
                    id: ("rt:" + $fid + "@" + $rv),
                    backend: "unknown",
                    runtime: { name: $fid, version: $rv }
                  }]
                  else []
                  end
                )
              }
            }
          ) | from_entries
        )
      }
    ') || return 1

    # ── Filesystem inspection pass ───────────────────────────────────────────
    # Refine entry_type and op by inspecting the real filesystem paths.
    local feature_id path entry_type op
    while IFS= read -r feature_id; do
        while IFS= read -r path; do
            if [[ -L "$path" ]]; then
                entry_type="symlink"
                op="link"
            elif [[ -d "$path" ]]; then
                entry_type="dir"
                op="copy"
            elif [[ -f "$path" ]]; then
                entry_type="file"
                op="copy"
            else
                # Path no longer exists; keep safe defaults
                entry_type="file"
                op="copy"
            fi

            intermediate=$(echo "$intermediate" | jq \
                --arg f "$feature_id" \
                --arg p "$path" \
                --arg et "$entry_type" \
                --arg op "$op" '
                .features[$f].resources = [
                    .features[$f].resources[] |
                    if .kind == "fs" and .fs.path == $p then
                        .fs.entry_type = $et | .fs.op = $op
                    else . end
                ]
            ') || return 1
        done < <(echo "$intermediate" | jq -r \
            --arg f "$feature_id" \
            '.features[$f].resources // [] | .[] | select(.kind == "fs") | .fs.path' \
            2>/dev/null)
    done < <(echo "$intermediate" | jq -r '.features | keys[]' 2>/dev/null)

    echo "$intermediate"
}

# ── Compat API ────────────────────────────────────────────────────────────────
# Compatibility API for Phase 4+ feature scripts.
#
# Status after Phase 4:
#   state_init, state_has_feature, state_list_features  → still used (keep)
#   state_get_packages, state_get_files, state_has_file  → still used (keep)
#   state_get_runtime, state_has_runtime                 → kept for reads
#   state_add_package, state_add_file                    → used by scripts for secondary pkgs/files
#   state_remove_feature, state_set_runtime              → DEPRECATED, see individual functions

# state_init
# Initialize or load state. Calls state_load (which auto-migrates v1 if needed).
state_init() {
    state_load
}

# state_has_feature <feature>
# Return 0 if the feature exists in state, 1 otherwise.
state_has_feature() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_has_feature: feature name is required"
        return 1
    fi
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -e --arg f "$feature" '.features[$f] != null' >/dev/null 2>&1
}

# state_list_features
# Output all installed feature names (one per line).
state_list_features() {
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -r '.features | keys[]' 2>/dev/null
}

# state_get_packages <feature>
# Output package names tracked for a feature (one per line).
state_get_packages() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_get_packages: feature name is required"
        return 1
    fi
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -r \
        --arg f "$feature" \
        '.features[$f].resources // [] | .[] | select(.kind == "package") | .package.name' \
        2>/dev/null
}

# state_get_files <feature>
# Output file paths tracked for a feature (one per line).
state_get_files() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_get_files: feature name is required"
        return 1
    fi
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -r \
        --arg f "$feature" \
        '.features[$f].resources // [] | .[] | select(.kind == "fs") | .fs.path' \
        2>/dev/null
}

# state_has_file <path>
# Return 0 if the path is tracked under any feature, 1 otherwise.
state_has_file() {
    local path="$1"
    if [[ -z "$path" ]]; then
        log_error "state_has_file: path is required"
        return 1
    fi
    _state_ensure_loaded || return 1
    echo "$_STATE_JSON" | jq -e \
        --arg p "$path" \
        '[.features | to_entries[] | .value.resources[] |
          select(.kind == "fs") | .fs.path] | index($p) != null' \
        >/dev/null 2>&1
}

# state_remove_feature <feature>
# DEPRECATED (Phase 4): use state_patch_remove_feature + state_patch_finalize instead.
# Executor calls state_patch_remove_feature; uninstall scripts no longer call this.
# Remove a feature entry from state and commit atomically.
state_remove_feature() {
    local feature="$1"
    if [[ -z "$feature" ]]; then
        log_error "state_remove_feature: feature name is required"
        return 1
    fi
    _state_ensure_loaded || return 1

    if ! echo "$_STATE_JSON" | jq -e --arg f "$feature" '.features[$f] != null' >/dev/null 2>&1; then
        log_warn "state_remove_feature: feature not found: $feature"
        return 0
    fi

    local new_json
    new_json=$(echo "$_STATE_JSON" | jq --arg f "$feature" 'del(.features[$f])')
    state_commit_atomic "$new_json"
}

# state_add_package <feature> <package_name>
# Register a package resource for a feature and commit atomically.
# Idempotent: replaces any existing resource with the same id.
state_add_package() {
    local feature="$1"
    local package_name="$2"

    if [[ -z "$feature" ]] || [[ -z "$package_name" ]]; then
        log_error "state_add_package: feature and package_name are required"
        return 1
    fi
    _state_ensure_loaded || return 1

    local resource
    resource=$(jq -n \
        --arg name "$package_name" '
        {
            kind: "package",
            id: ("pkg:" + $name),
            backend: "unknown",
            package: { name: $name, version: null }
        }
    ')

    local new_json
    new_json=$(echo "$_STATE_JSON" | jq \
        --arg f "$feature" \
        --argjson res "$resource" '
        if .features[$f] == null then
            .features[$f] = {"resources": []}
        else . end |
        .features[$f].resources = (
            [.features[$f].resources[] | select(.id != $res.id)] + [$res]
        )
    ')
    state_commit_atomic "$new_json"
}

# state_add_file <feature> <path>
# Register an fs resource for a feature and commit atomically.
# entry_type and op are inferred from the filesystem at call time.
# Idempotent: replaces any existing resource with the same id.
state_add_file() {
    local feature="$1"
    local path="$2"

    if [[ -z "$feature" ]] || [[ -z "$path" ]]; then
        log_error "state_add_file: feature and path are required"
        return 1
    fi
    _state_ensure_loaded || return 1

    # Infer entry_type and op from the actual filesystem entry
    local entry_type op
    if [[ -L "$path" ]]; then
        entry_type="symlink"
        op="link"
    elif [[ -d "$path" ]]; then
        entry_type="dir"
        op="copy"
    elif [[ -f "$path" ]]; then
        entry_type="file"
        op="copy"
    else
        entry_type="file"
        op="copy"
    fi

    local resource
    resource=$(jq -n \
        --arg path "$path" \
        --arg et "$entry_type" \
        --arg op "$op" '
        {
            kind: "fs",
            id: ("fs:" + $path),
            fs: {
                path: $path,
                entry_type: $et,
                op: $op
            }
        }
    ')

    local new_json
    new_json=$(echo "$_STATE_JSON" | jq \
        --arg f "$feature" \
        --argjson res "$resource" '
        if .features[$f] == null then
            .features[$f] = {"resources": []}
        else . end |
        .features[$f].resources = (
            [.features[$f].resources[] | select(.id != $res.id)] + [$res]
        )
    ')
    state_commit_atomic "$new_json"
}

# state_set_runtime <feature> <key> <value>
# DEPRECATED (Phase 4): executor writes runtime resources from meta.yaml declarations.
# Feature scripts no longer call this function.
# Register (or replace) a runtime resource for a feature.
state_set_runtime() {
    local feature="$1"
    local key="$2"
    local value="$3"

    if [[ -z "$feature" ]] || [[ -z "$key" ]]; then
        log_error "state_set_runtime: feature and key are required"
        return 1
    fi
    _state_ensure_loaded || return 1

    if [[ "$key" != "version" ]]; then
        # Non-version keys are not mapped to v2 resources; silently ignore.
        # Will be re-evaluated when feature scripts are rewritten in Phase 4.
        return 0
    fi

    local resource
    resource=$(jq -n \
        --arg fid "$feature" \
        --arg ver "$value" '
        {
            kind: "runtime",
            id: ("rt:" + $fid + "@" + $ver),
            backend: "unknown",
            runtime: { name: $fid, version: $ver }
        }
    ')

    # Replace any existing runtime resource for this feature (version change)
    local new_json
    new_json=$(echo "$_STATE_JSON" | jq \
        --arg f "$feature" \
        --argjson res "$resource" '
        if .features[$f] == null then
            .features[$f] = {"resources": []}
        else . end |
        .features[$f].resources = (
            [.features[$f].resources[] | select(.kind != "runtime")] + [$res]
        )
    ')
    state_commit_atomic "$new_json"
}

# state_get_runtime <feature> <key>
# Return the value for <key> from the runtime resource of a feature.
# Only key="version" is supported; returns the runtime.version string.
state_get_runtime() {
    local feature="$1"
    local key="$2"

    if [[ -z "$feature" ]] || [[ -z "$key" ]]; then
        log_error "state_get_runtime: feature and key are required"
        return 1
    fi
    _state_ensure_loaded || return 1

    if [[ "$key" != "version" ]]; then
        return 0
    fi

    echo "$_STATE_JSON" | jq -r \
        --arg f "$feature" \
        '.features[$f].resources // [] |
         .[] | select(.kind == "runtime") | .runtime.version' \
        2>/dev/null | head -n1
}

# state_has_runtime <feature> <key>
# Return 0 if a runtime resource exists for the feature, 1 otherwise.
state_has_runtime() {
    local feature="$1"
    local key="$2"

    if [[ -z "$feature" ]] || [[ -z "$key" ]]; then
        log_error "state_has_runtime: feature and key are required"
        return 1
    fi
    _state_ensure_loaded || return 1

    if [[ "$key" != "version" ]]; then
        return 1
    fi

    echo "$_STATE_JSON" | jq -e \
        --arg f "$feature" \
        '.features[$f].resources // [] |
         [.[] | select(.kind == "runtime")] | length > 0' \
        >/dev/null 2>&1
}
