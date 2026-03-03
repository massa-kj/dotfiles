# Planner Spec

## 0. Scope

This document defines:

* planner responsibilities
* plan data model
* decision table contract
* execution boundary
* interaction between planner / executor / state / backend

This document does NOT define:

* state schema (see STATE_SPEC)
* backend API (see CORE)
* profile schema
* policy schema

---

# 1. Architectural Boundary

## 1.1 Planner is PURE

Planner MUST:

* read inputs
* compute classification
* decide actions
* produce a plan

Planner MUST NOT:

* execute install/uninstall
* modify state
* call backend plugins
* modify filesystem
* read or write external environment

Planner is a **pure decision engine**.

---

## 1.2 Executor is IMPURE

Executor MUST:

* execute actions in order
* call feature scripts
* call backend plugins
* perform filesystem operations (via fs module)
* collect execution results
* generate state patch
* commit state atomically

Executor MUST NOT:

* decide actions
* re-classify operations
* override plan decisions

Executor executes, never decides.

---

# 2. Inputs to Planner

Planner MUST operate only on:

1. `profile` (desired state)
2. `state` (current authoritative state)
3. `policy` (backend resolution strategy)
4. `inventory` (optional observational layer, read-only)

Planner MUST NOT depend on:

* current time
* environment randomness
* backend live results (except via inventory snapshot prepared beforehand)

---

# 3. Planner Phases

Planner MUST consist of three conceptual phases:

```
Diff → Classification → Decision
```

---

# 3.1 Diff Phase (PURE)

### Input:

* profile
* state

### Output:

* structural diff object

Diff MUST determine:

* features present in profile but not in state
* features present in state but not in profile
* features present in both but with resource mismatch
* per-resource version/backend mismatch

Diff MUST NOT:

* consider policy
* consider inventory
* perform capability resolution

Diff is structural only.

---

# 3.2 Classification Phase (PURE)

Classification MUST convert structural diff into normalized cases.

Each feature MUST be classified into exactly one of:

* `create`
* `destroy`
* `replace`
* `replace_backend`
* `strengthen`
* `noop`
* `blocked`

Definitions:

### create

Feature not in state → desired in profile

### destroy

Feature in state → not desired in profile

### replace

Feature in state → desired but version mismatch

### replace_backend

Feature in state → desired but backend mismatch

### strengthen

Feature in state → desired with additional resources

### noop

Feature in state → matches desired exactly

### blocked

Feature contains unknown kind or invariant violation

Classification MUST NOT perform execution.

---

# 3.3 Decision Phase (PURE)

Decision MUST:

* take classification
* consult decision table
* produce ordered action list

Decision MUST NOT:

* call backend
* modify state
* inspect filesystem

---

# 4. Decision Table Contract

Planner MUST use a deterministic decision table.

Example minimal contract:

| Current State | Desired State | Action          |
| ------------- | ------------- | --------------- |
| ∅             | managed       | create          |
| managed(v1)   | managed(v2)   | replace         |
| managed       | ∅             | destroy         |
| managed(A)    | managed(B)    | replace_backend |

Decision table MUST be:

* deterministic
* total (every classification must map to an action)
* explicit (no hidden fallback)

---

# 5. Plan Data Model

Planner MUST output a structured plan object:

```json
{
  "actions": [
    {
      "feature": "git",
      "operation": "create"
    },
    {
      "feature": "node",
      "operation": "replace",
      "details": {
        "from_version": "18",
        "to_version": "20"
      }
    }
  ],
  "blocked": [
    {
      "feature": "legacy-feature",
      "reason": "unknown resource kind: registry"
    }
  ],
  "summary": {
    "create": 1,
    "replace": 1,
    "destroy": 0,
    "blocked": 1
  }
}
```

Constraints:

* Plan MUST contain ordered `actions`.
* Plan MUST contain explicit `blocked` list.
* Plan MUST contain summary counts.
* Plan MUST be serializable (for future JSON output).

---

# 6. Ordering Rules

Planner MUST enforce:

1. destroy operations in reverse dependency order
2. replace operations as:

   * uninstall first
   * then install
3. create operations in dependency order
4. replace_backend treated as replace

Dependency order MUST be derived from resolver output.

Planner MUST NOT rely on feature script order.

---

# 7. Plan Command (`dotfiles plan`)

## 7.1 Responsibilities

`plan` command MUST:

* call planner
* print plan
* NEVER execute actions
* NEVER modify state

## 7.2 Interactive Mode

If interactive mode exists:

* Planner MUST NOT modify profile directly.
* Interactive mode MAY generate a patch proposal.
* Writing profile changes MUST require explicit user confirmation.
* Automatic silent profile rewrite is forbidden.

---

# 8. Apply Command (`dotfiles apply`)

`apply` MUST:

1. run planner
2. if blocked features exist:

   * report each blocked feature with its reason
   * skip blocked features (do not execute their actions)
   * continue execution of remaining non-blocked actions

   Note: "blocked" means a planner-level classification (e.g. unknown resource
   kind in state). It is distinct from an executor-level failure (script error).
   Executor failures cause an immediate full abort.
3. pass plan to executor
4. commit state only after successful execution

`apply` MUST NOT:

* re-run classification in executor
* override decision table

---

# 9. State Commit Discipline

Executor MUST:

* execute feature-level operation as atomic unit
* after successful operation:

  * generate state patch
  * commit atomically
* if failure occurs:

  * do NOT commit partial state
  * abort immediately

Planner MUST NOT influence state commit timing.

---

# 10. Determinism Guarantee

Given identical:

* profile
* state
* policy
* feature metadata

Planner MUST produce identical plan.

No randomness permitted.

---

# 11. Forbidden Coupling

Planner MUST NOT:

* read backend plugin directly
* inspect filesystem for drift decisions
* contain feature-specific special cases
* embed platform logic

If special logic is needed, it MUST be represented via:

* classification rule
* decision table entry
* or state contract

---

# 12. Future Extensibility

Planner design MUST allow:

* migrate-state
* migrate-backend
* drift-detection extension
* additional resource kinds

Extensibility MUST NOT:

* break decision table determinism
* introduce feature-specific branching

---

# 13. Summary of Boundaries

| Layer    | Responsibility         |
| -------- | ---------------------- |
| resolver | DAG construction       |
| planner  | classify + decide      |
| executor | execute + state commit |
| state    | authority + atomicity  |
| backend  | execution adapter      |

These boundaries are non-negotiable.
