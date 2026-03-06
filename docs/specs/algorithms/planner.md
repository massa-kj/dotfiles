# Planner Specification

## Scope

This document defines the normative contract for the planner.

Covered: planner boundary, inputs, phases (diff/classification/decision),
decision table, plan data model, ordering rules, and determinism guarantee.

Not covered: state schema (see `specs/data/state.md`),
backend API (see `specs/api/backend.md`), executor behavior.

## Planner Boundary

Planner is **pure**.

Planner must: read inputs, compute classification, produce a plan.
Planner must NOT: execute install/uninstall, modify state, call backends, modify filesystem.

Executor must: execute actions in plan order, commit state atomically.
Executor must NOT: decide actions, re-classify, override plan decisions.

## Inputs

Planner operates only on:

1. `profile` — desired state
2. `state` — current authoritative state
3. `policy` — backend resolution strategy

Planner must NOT depend on current time, environment randomness, or live backend results.
Planner must NOT call backend observation API.
Environment detection via backend observation API is performed by the `plan` command layer,
not by the planner itself, and does not affect classification decisions.

## Planner Phases

```
Diff → Classification → Decision
```

**Diff** — structural comparison of profile vs state.
Determines: features added, removed, changed (version/resource mismatch).
Must not consider policy.

**Classification** — converts diff into normalized cases.
Each feature is classified into exactly one of:
`create | destroy | replace | replace_backend | strengthen | noop | blocked`

| Class | Condition |
|---|---|
| `create` | In profile, not in state |
| `destroy` | In state, not in profile |
| `replace` | In both, version mismatch |
| `replace_backend` | In both, backend mismatch |
| `strengthen` | In both, state has fewer resources than desired |
| `noop` | In both, matches desired exactly |
| `blocked` | Unknown resource kind or invariant violation in state |

**Decision** — maps classification to ordered action list using the decision table.
Must not call backends, modify state, or inspect filesystem.

## Decision Table

| Current State | Desired State | Action |
|---|---|---|
| ∅ | managed | `create` |
| managed(v1) | managed(v2) | `replace` |
| managed | ∅ | `destroy` |
| managed(A) | managed(B) | `replace_backend` |

Table must be deterministic, total (every classification maps to an action), and explicit (no hidden fallbacks).

## Plan Data Model

```json
{
  "actions": [
    { "feature": "git", "operation": "create" },
    { "feature": "node", "operation": "replace", "details": { "from_version": "18", "to_version": "20" } }
  ],
  "noops": [ { "feature": "bash" } ],
  "blocked": [ { "feature": "legacy", "reason": "unknown resource kind: registry" } ],
  "summary": { "create": 1, "replace": 1, "destroy": 0, "blocked": 1 }
}
```

* `actions` — ordered list of operations to execute
* `noops` — features already correct; not in `actions`
* `blocked` — features skipped due to planner-level classification
* `summary` — counts per operation type

## Ordering Rules

1. `destroy` operations in reverse dependency order
2. `replace` operations: uninstall first, then install
3. `create` operations in dependency order
4. `replace_backend` treated as `replace`

Ordering must be derived from resolver output. Must not rely on feature script order.

## Plan Command

`dotfiles plan` must: call planner, print plan, never execute actions, never modify state.

## Apply Interaction

`dotfiles apply` must: run planner → report blocked features → pass plan to executor → commit state.
Blocked features are skipped; non-blocked features continue.
Apply must not re-run classification inside the executor.

## Determinism Guarantee

Given identical profile, state, policy, and feature metadata:
the planner must produce an identical plan. No randomness permitted.
