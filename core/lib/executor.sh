#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Module: executor
#
# Responsibility:
#   IMPURE executor. Receives a plan JSON object from planner and executes it.
#   Calls feature scripts, manages state after each successful operation.
#
# Public API:
#   executor_run <plan_json>
#
# Execution contract:
#   - Blocked features in plan.blocked are reported and skipped.
#   - Actions are executed in plan.actions order (destroy → replace → create).
#   - For `replace`: uninstall script runs first, then install script.
#   - On any script failure: abort immediately with non-zero exit.
#     Partial execution is left in place; state reflects what succeeded.
#
# State commit (Phase 3 note):
#   Feature scripts currently call compat state APIs (state_add_package etc.)
#   which commit state atomically on their own. Executor does not do additional
#   state commits in Phase 3.
#   Phase 4 will rewrite feature scripts to be state-free; at that point
#   executor will be responsible for all state_patch_begin / state_patch_finalize
#   / state_commit_atomic calls.
# -----------------------------------------------------------------------------

# This library expects env.sh, logger.sh, state.sh to be sourced by the caller.

# ── Internal helpers ──────────────────────────────────────────────────────────

# _executor_run_script <script_path> [env_vars...]
# Run a feature script as a subprocess.
# Extra arguments are exported as environment variables for the subprocess.
# Returns the script exit code.
_executor_run_script() {
    local script="$1"
    shift

    if [[ ! -f "$script" ]]; then
        log_error "executor: script not found: $script"
        return 1
    fi

    # Set extra env vars if provided (NAME=value format)
    local -a env_args=()
    for arg in "$@"; do
        env_args+=("$arg")
    done

    if [[ ${#env_args[@]} -gt 0 ]]; then
        env "${env_args[@]}" bash "$script"
    else
        bash "$script"
    fi
}

# _executor_destroy <feature>
# Run uninstall script for a feature. Aborts executor on failure.
_executor_destroy() {
    local feature="$1"
    local script="$DOTFILES_FEATURES_DIR/$feature/uninstall.sh"

    log_info "Destroying: $feature"
    if ! _executor_run_script "$script"; then
        log_error "executor: failed to uninstall feature: $feature"
        return 1
    fi
}

# _executor_install <feature> <config_version>
# Run install script for a feature. Aborts executor on failure.
_executor_install() {
    local feature="$1"
    local config_version="${2:-}"
    local script="$DOTFILES_FEATURES_DIR/$feature/install.sh"

    log_info "Installing: $feature"

    local -a env_args=()
    if [[ -n "$config_version" ]]; then
        env_args+=("DOTFILES_FEATURE_CONFIG_VERSION=$config_version")
    fi

    if ! _executor_run_script "$script" "${env_args[@]}"; then
        log_error "executor: failed to install feature: $feature"
        return 1
    fi
}

# _executor_replace <feature> <config_version>
# Uninstall then re-install a feature (version or backend replacement).
_executor_replace() {
    local feature="$1"
    local config_version="${2:-}"
    local uninstall_script="$DOTFILES_FEATURES_DIR/$feature/uninstall.sh"

    log_info "Replacing: $feature"
    if ! _executor_run_script "$uninstall_script"; then
        log_error "executor: failed to uninstall before replace: $feature"
        return 1
    fi

    _executor_install "$feature" "$config_version" || return 1
}

# ── Plan reporting ────────────────────────────────────────────────────────────

# _executor_report_blocked <plan_json>
# Log blocked features (they are skipped, not aborted).
_executor_report_blocked() {
    local plan_json="$1"
    local count
    count=$(echo "$plan_json" | jq '.blocked | length')
    if [[ "$count" -gt 0 ]]; then
        log_warn "Skipping $count blocked feature(s):"
        while IFS= read -r line; do
            log_warn "  ⊘ $line"
        done < <(echo "$plan_json" | jq -r '.blocked[] | "\(.feature): \(.reason)"')
    fi
}

# _executor_report_summary <plan_json>
# Print plan action summary to log.
_executor_report_summary() {
    local plan_json="$1"
    local create destroy replace blocked noop
    create=$(echo "$plan_json" | jq '.summary.create')
    destroy=$(echo "$plan_json" | jq '.summary.destroy')
    replace=$(echo "$plan_json" | jq '.summary.replace')
    blocked=$(echo "$plan_json" | jq '.summary.blocked')
    noop=$(echo "$plan_json" | jq '.summary.noop')
    log_info "Plan: create=$create  destroy=$destroy  replace=$replace  noop=$noop  blocked=$blocked"
}

# ── Public API ────────────────────────────────────────────────────────────────

# executor_run <plan_json>
# Execute all actions in plan_json.
#
# Blocked features are reported and skipped.
# Any action failure causes immediate abort (non-zero exit).
executor_run() {
    local plan_json="$1"

    if [[ -z "$plan_json" ]]; then
        log_error "executor_run: plan_json is required"
        return 1
    fi

    # Validate plan is parseable
    if ! echo "$plan_json" | jq empty 2>/dev/null; then
        log_error "executor_run: plan_json is not valid JSON"
        return 1
    fi

    _executor_report_blocked "$plan_json"
    _executor_report_summary "$plan_json"

    local action_count
    action_count=$(echo "$plan_json" | jq '.actions | length')

    if [[ "$action_count" -eq 0 ]]; then
        log_info "Nothing to do."
        return 0
    fi

    log_task "Executing plan ($action_count actions)..."

    local i
    for ((i = 0; i < action_count; i++)); do
        local action feature operation config_version
        action=$(echo "$plan_json" | jq --argjson i "$i" '.actions[$i]')
        feature=$(echo "$action" | jq -r '.feature')
        operation=$(echo "$action" | jq -r '.operation')
        config_version=$(echo "$action" | jq -r '.details.config_version // empty')

        case "$operation" in
            destroy)
                _executor_destroy "$feature" || return 1
                ;;
            create)
                _executor_install "$feature" "$config_version" || return 1
                ;;
            replace|replace_backend)
                _executor_replace "$feature" "$config_version" || return 1
                ;;
            *)
                log_error "executor: unknown operation '$operation' for feature '$feature'"
                return 1
                ;;
        esac
    done

    return 0
}
