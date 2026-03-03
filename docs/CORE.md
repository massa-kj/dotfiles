# Core

## Core is

* engine
* safety boundary
* orchestration brain

Core MUST remain stable.

Features are replaceable.
Backends are replaceable.
Platforms are replaceable.

## Core responsibilities (normative)

Core MUST:

1. Load inputs: profile, policy, state
2. Resolve feature graph (depends / requires-provides)
3. Produce an execution plan (decision table / planner)
4. Execute plan deterministically (no implicit fallback)
5. Commit state only on successful operations
6. Enforce safety rules (no untracked deletion, atomic state writes)

Core MUST NOT:

* contain feature-specific logic
* contain manager-specific logic (brew/scoop/mise/winget etc.)
* let plugins read policy or write state directly
* infer installed resources by scanning the system for uninstall decisions

## Layering (re-confirm)

* profiles = intent (What)
* policy = strategy (How, incl backend selection)
* state = effects (authority)
* features = implementation units
* backends = execution adapters

## Module structure (proposed)

```
core/lib/
├── env                # paths, platform detection, validation
├── resolver           # load meta, build DAG, topo sort
├── planner            # diff + classify + decide actions (pure)
├── executor           # run actions, call features/backends, collect results
├── state              # load/validate/atomic commit
├── backend_registry   # resolve + load backend plugin, stable backend API gate
├── fs                 # safe file operations (copy/link/backup/remove tracked)
├── runner             # execute shell/pwsh consistently
└── logger             # structured logging
```

## Backend Plugin Contract (normative)

Backend plugin MUST:

* implement required functions for supported operations
* be idempotent for install/uninstall operations
* NOT read policy
* NOT write state
* NOT perform cross-feature decisions

Backend plugin MAY:

* check “manager exists” / “package exists” for plan observation only

Backend plugin MUST expose:

* `backend_api_version`
* `backend_capabilities` (optional)

And operations (if capability supported):

* `backend_install_package(name, version|null)`
* `backend_uninstall_package(name, version|null)`
* `backend_install_runtime(name, version)`
* `backend_uninstall_runtime(name, version)`

Observation (plan use):

* `backend_manager_exists()`
* `backend_package_exists(name, version|null)`
* `backend_runtime_exists(name, version)`

## Determinism rules (normative)

Given the same (profile, policy, state, feature set), core MUST:

* produce the same plan
* execute in the same order
* commit the same state changes

Core MUST NOT introduce:

* randomization
* time-based branching
* implicit fallback without being represented in plan

## Error policy (normative)

* Any failure stops execution.
* No automatic retries.
* No partial state commits.
* If state commit fails → abort.

## Compatibility expectations (normative)

Breaking changes include:

* state schema version bump
* stable API signature changes (state/backend_registry/resolver/planner)

When breaking:

* MUST provide migration guidance
* MUST update STATE_SPEC.md / CORE.md accordingly
