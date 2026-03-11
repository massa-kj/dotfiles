# Resolver Specification

## Scope

This document defines the input/output contract and algorithm for the resolver.

Covered: inputs, metadata sources, dependency model, graph construction, cycle detection, output contract.

Not covered: execution, state mutations, planner decision logic.

## Inputs

The resolver receives:

* `desired_features` — list of canonical feature identifiers from the resolved profile

All resolver inputs must already be normalized to canonical IDs of the form `<source_id>/<name>`.
Bare names are normalized upstream to `core/<name>` before resolver execution.

## Metadata Sources

For each feature, the resolver determines the source-specific feature directory via the source registry.

Feature root resolution:

* `core/<name>` → `{repo}/features/<name>`
* `user/<name>` → config home `features/<name>`
* `<external>/<name>` → data home `sources/<external>/features/<name>`

Within that feature directory, the resolver reads:

1. `meta.yaml` — base metadata (always present)
2. `meta.<platform>.yaml` — platform-specific overrides (merged if present)

Platform resolution order:

* WSL: `meta.wsl.yaml` → `meta.linux.yaml` → none
* Linux: `meta.linux.yaml` → none
* Windows: `meta.windows.yaml` → none

Fields read from metadata:

* `depends[]` — list of explicit feature identifiers
* `provides[].name` — capability names this feature exposes
* `requires[].name` — capability names this feature depends on

External and `user` features are subject to source allow-list validation.
If the feature itself or any declared explicit dependency is not allowed by the source registry,
resolution must abort.

## Dependency Model

**`depends`** — explicit feature dependency.
Use when the dependency is on a specific named feature.

```yaml
depends:
  - git
```

Normalization rules for `depends`:

* bare name `git` in `core/neovim` → `core/git`
* bare name `helper` in `user/myfeat` → `user/helper`
* cross-source dependency must be explicit, e.g. `core/git` or `community/node`

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

1. Read metadata for all desired features from their source-specific directories.
2. Normalize `depends` entries to canonical IDs and build explicit dependency edges.
3. For each feature with `requires`, find matching `provides` among desired features.
   Inject found providers as implicit `depends` edges.
4. If a required capability has no provider in the desired set, abort with an error.
5. If an explicit dependency is not present in the desired set, abort with an error.

## Cycle Detection

The resolver performs depth-first search with an in-stack marker.
If a feature is encountered while it is already in the DFS stack, a cycle is detected and execution aborts.

Cycles are forbidden. The dependency graph must be a DAG.

## Output Contract

The resolver outputs a topologically sorted list of canonical feature identifiers.

* Install order: dependencies appear before dependents.
* Uninstall order: reverse of install order (managed by planner/executor).
* If a dependency declared in `depends` is not present in the desired set, execution aborts.
* Resolver output is deterministic for the same canonical input set and metadata.
