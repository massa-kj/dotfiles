#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: planner
#
# Responsibility:
#   PURE decision engine. Converts (profile, state, policy) into a structured
#   plan object describing what the executor should do. Never executes anything.
#
# Public API:
#   planner_run <profile_file> <sorted_features_nameref>  → plan JSON (stdout)
#
# Internal phases (each PURE function):
#   _planner_diff       profile × state → diff JSON array
#   _planner_classify   diff JSON → classified JSON array
#   _planner_decide     classified JSON × sorted order → plan JSON
#
# Plan JSON schema:
#   {
#     "actions": [
#       {"feature": "git", "operation": "create",
#        "details": {"config_version": null}},
#       {"feature": "node", "operation": "replace",
#        "details": {"from_version": "20.0.0", "to_version": "22",
#                    "config_version": "22"}}
#     ],
#     "blocked": [
#       {"feature": "legacy", "reason": "unknown resource kind: registry"}
#     ],
#     "summary": {"create": 1, "destroy": 0, "replace": 1,
#                 "replace_backend": 0, "strengthen": 0,
#                 "noop": 2, "blocked": 1}
#   }
#
# Action ordering (per PLANNER_SPEC §6):
#   1. destroy   – reverse dependency order
#   2. replace   – dependency order
#   3. create    – dependency order
#
# Classification table:
#   in_profile=false, in_state=true                       → destroy
#   in_profile=true,  in_state=false                      → create
#   in_profile=true,  in_state=true, version mismatch     → replace
#   in_profile=true,  in_state=true, has unknown resource → blocked
#   in_profile=true,  in_state=true, no mismatch          → noop
# -----------------------------------------------------------------------------

# This module reads _STATE_JSON and _BR_POLICY_DATA as READ-ONLY inputs.
# It MUST NOT write to any module-global variable.

# Valid resource kinds; anything else causes a "blocked" classification.
readonly _PLANNER_VALID_KINDS="package runtime fs"

# ── Profile helpers ───────────────────────────────────────────────────────────

# _planner_load_profile <profile_file>
# Print the raw YAML content of a profile file to stdout.
_planner_load_profile() {
    cat "$1"
}

# _planner_profile_version <profile_data> <feature>
# Extract .features.<feature>.version from profile YAML data.
# Prints the version string, or empty if not specified.
_planner_profile_version() {
    local profile_data="$1"
    local feature="$2"
    echo "$profile_data" | yq eval ".features.${feature}.version // \"\"" - 2>/dev/null
}

# ── State helpers (read-only) ─────────────────────────────────────────────────

# _planner_state_runtime_version <feature>
# Extract the runtime resource version for a feature from state JSON.
# Prints the version string, or empty if none.
_planner_state_runtime_version() {
    local feature="$1"
    echo "$_STATE_JSON" | jq -r --arg f "$feature" \
        '.features[$f].resources // [] | map(select(.kind == "runtime")) | first | .version // ""'
}

# _planner_state_has_unknown_kind <feature>
# Return 0 if the feature has any resource with an unrecognised kind, 1 otherwise.
_planner_state_has_unknown_kind() {
    local feature="$1"
    local count
    count=$(echo "$_STATE_JSON" | jq --arg f "$feature" \
        '.features[$f].resources // [] | map(select(.kind | IN("package","runtime","fs") | not)) | length')
    [[ "$count" -gt 0 ]]
}

# _planner_state_unknown_kinds_csv <feature>
# Print comma-separated list of unrecognised resource kinds (for error messages).
_planner_state_unknown_kinds_csv() {
    local feature="$1"
    echo "$_STATE_JSON" | jq -r --arg f "$feature" \
        '.features[$f].resources // [] | map(select(.kind | IN("package","runtime","fs") | not)) | map(.kind) | unique | join(", ")'
}

# ── Phase 1: Diff ─────────────────────────────────────────────────────────────

# _planner_diff <profile_data> <sorted_features_nameref>
# Compare desired features (profile) against current state.
# Outputs a JSON array of diff objects to stdout.
#
# Diff object schema:
#   {
#     "feature": string,
#     "in_profile": bool,
#     "in_state": bool,
#     "version_desired": string | null,
#     "version_installed": string | null,
#     "has_blocked_resources": bool,
#     "blocked_reason": string | null
#   }
_planner_diff() {
    local profile_data="$1"
    local -n _diff_sorted="$2"

    local diff_json="[]"

    # ── Desired features (in sorted dependency order) ──
    for feature in "${_diff_sorted[@]}"; do
        local in_state
        in_state=$(echo "$_STATE_JSON" | jq -r --arg f "$feature" \
            'if .features[$f] then "true" else "false" end')

        local version_desired
        version_desired=$(_planner_profile_version "$profile_data" "$feature")

        local version_installed="null"
        local has_blocked="false"
        local blocked_reason="null"

        if [[ "$in_state" == "true" ]]; then
            local rv
            rv=$(_planner_state_runtime_version "$feature")
            [[ -n "$rv" ]] && version_installed="\"$rv\""

            if _planner_state_has_unknown_kind "$feature"; then
                has_blocked="true"
                local kinds
                kinds=$(_planner_state_unknown_kinds_csv "$feature")
                blocked_reason="\"unknown resource kind: $kinds\""
            fi
        fi

        diff_json=$(echo "$diff_json" | jq \
            --arg f "$feature" \
            --argjson in_state "$in_state" \
            --argjson vd "$([ -z "$version_desired" ] && echo "null" || echo "\"$version_desired\"")" \
            --argjson vi "$version_installed" \
            --argjson hb "$has_blocked" \
            --argjson br "$blocked_reason" \
            '. + [{
                feature:               $f,
                in_profile:            true,
                in_state:              $in_state,
                version_desired:       $vd,
                version_installed:     $vi,
                has_blocked_resources: $hb,
                blocked_reason:        $br
            }]')
    done

    # ── Installed features not in profile (candidates for destroy) ──
    local installed_features
    mapfile -t installed_features < <(echo "$_STATE_JSON" | jq -r '.features | keys[]')

    for feature in "${installed_features[@]}"; do
        # Skip if already processed above
        if [[ " ${_diff_sorted[*]} " =~ " ${feature} " ]]; then
            continue
        fi

        diff_json=$(echo "$diff_json" | jq \
            --arg f "$feature" \
            '. + [{
                feature:               $f,
                in_profile:            false,
                in_state:              true,
                version_desired:       null,
                version_installed:     null,
                has_blocked_resources: false,
                blocked_reason:        null
            }]')
    done

    echo "$diff_json"
}

# ── Phase 2: Classification ───────────────────────────────────────────────────

# _planner_classify <diff_json>
# Apply the decision table to each diff entry.
# Outputs a JSON array of classified objects to stdout.
#
# Classified object schema:
#   {feature, classification, from_version?, to_version?, reason?}
_planner_classify() {
    local diff_json="$1"

    echo "$diff_json" | jq '[.[] |
        # Decision table — explicit, no hidden fallback
        if .has_blocked_resources then
            {
                feature:        .feature,
                classification: "blocked",
                reason:         (.blocked_reason // "unknown resource kind in state")
            }
        elif (.in_profile and (.in_state | not)) then
            {
                feature:          .feature,
                classification:   "create",
                desired_version:  .version_desired
            }
        elif ((.in_profile | not) and .in_state) then
            {
                feature:        .feature,
                classification: "destroy"
            }
        elif (.in_profile and .in_state) then
            if (.version_desired != null and .version_desired != .version_installed) then
                {
                    feature:        .feature,
                    classification: "replace",
                    from_version:   .version_installed,
                    to_version:     .version_desired
                }
            else
                {
                    feature:        .feature,
                    classification: "noop"
                }
            end
        else
            # Unreachable given diff semantics, but table must be total
            {feature: .feature, classification: "noop"}
        end
    ]'
}

# ── Phase 3: Decision ─────────────────────────────────────────────────────────

# _planner_decide <classified_json>
# Apply ordering rules and produce the final plan JSON.
# Ordering (PLANNER_SPEC §6):
#   1. destroy  – reverse order (reverse of their position in classified list)
#   2. replace  – same order as classified (dependency order)
#   3. create   – same order as classified (dependency order)
_planner_decide() {
    local classified_json="$1"

    echo "$classified_json" | jq '
        . as $items |

        ($items | map(select(.classification == "destroy"))  | reverse)  as $destroys |
        ($items | map(select(.classification == "replace")))             as $replaces |
        ($items | map(select(.classification == "create")))              as $creates  |
        ($items | map(select(.classification == "blocked")))             as $blocked  |
        ($items | map(select(.classification == "noop")))                as $noops    |

        # Build ordered actions array
        (
            [ $destroys[] | {
                feature:   .feature,
                operation: "destroy",
                details:   {}
            }] +
            [ $replaces[] | {
                feature:   .feature,
                operation: "replace",
                details:   {
                    from_version:   .from_version,
                    to_version:     .to_version,
                    config_version: .to_version
                }
            }] +
            [ $creates[] | {
                feature:   .feature,
                operation: "create",
                details:   {
                    config_version: .desired_version
                }
            }]
        ) as $actions |

        {
            actions: $actions,
            blocked: ($blocked | map({
                feature: .feature,
                reason:  (.reason // "unknown resource kind in state")
            })),
            summary: {
                create:          ($creates  | length),
                destroy:         ($destroys | length),
                replace:         ($replaces | length),
                replace_backend: 0,
                strengthen:      0,
                noop:            ($noops    | length),
                blocked:         ($blocked  | length)
            }
        }
    '
}

# ── Public API ────────────────────────────────────────────────────────────────

# planner_run <profile_file> <sorted_features_nameref>
# Full planning pipeline: diff → classify → decide.
# Outputs plan JSON to stdout.
#
# Inputs (read-only module globals):
#   _STATE_JSON       — loaded state (from state_load / state_init)
#   _BR_POLICY_DATA   — loaded policy (from backend_registry_load_policy)
planner_run() {
    local profile_file="$1"
    local sorted_features_ref="$2"
    local -n _pr_sorted="$sorted_features_ref"

    if [[ ! -f "$profile_file" ]]; then
        log_error "planner_run: profile file not found: $profile_file"
        return 1
    fi

    local profile_data
    profile_data=$(_planner_load_profile "$profile_file")

    local diff_json
    diff_json=$(_planner_diff "$profile_data" "$sorted_features_ref") || return 1

    local classified_json
    classified_json=$(_planner_classify "$diff_json") || return 1

    _planner_decide "$classified_json"
}
