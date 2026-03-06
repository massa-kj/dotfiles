# Resolver Specification (Draft)

This spec is derived from the current implementation in `core/lib/resolver.sh`.
It is a working document for design review. Sections may be revised as the design evolves.

## Scope

This document defines the input/output contract and algorithm for the resolver.

Covered: inputs, metadata sources, dependency model, graph construction, cycle detection, output contract.

Not covered: execution, state mutations, planner decision logic.

## Inputs

The resolver receives:

* `desired_features` — list of feature identifiers from the resolved profile

## Metadata Sources

For each feature, the resolver reads:

1. `features/<name>/meta.yaml` — base metadata (always present)
2. `features/<name>/meta.<platform>.yaml` — platform-specific overrides (merged if present)

Platform resolution order for WSL: `meta.wsl.yaml` → `meta.linux.yaml` → (none)

Fields read from metadata:

* `depends[]` — list of explicit feature identifiers
* `provides[].name` — capability names this feature exposes
* `requires[].name` — capability names this feature depends on

## Dependency Model

**`depends`** — explicit feature dependency.
Use when the dependency is on a specific named feature.

```yaml
depends:
  - git
```

**`provides` / `requires`** — capability-based dependency.
Use when a feature needs any provider of an abstract capability.

```yaml
# provider
provides:
  - name: package_manager

# consumer
requires:
  - name: package_manager
```

The resolver finds all features in the desired set that declare the matching `provides` entry,
and injects them as implicit ordering dependencies of the requiring feature.

## Graph Construction

1. Read metadata for all desired features.
2. Build explicit dependency edges from `depends`.
3. For each feature with `requires`, find matching `provides` among desired features.
   Inject found providers as implicit `depends` edges.
4. If a required capability has no provider in the desired set, abort with an error.

## Cycle Detection

The resolver performs depth-first search with an in-stack marker.
If a feature is encountered while it is already in the DFS stack, a cycle is detected and execution aborts.

Cycles are forbidden. The dependency graph must be a DAG.

## Output Contract

The resolver outputs a topologically sorted list of feature identifiers.

* Install order: dependencies appear before dependents.
* Uninstall order: reverse of install order (managed by planner/executor).
* If a dependency declared in `depends` is not present in the desired set, execution aborts.
