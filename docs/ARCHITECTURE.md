# Architecture

Profiles declare intent.
Core provides primitives.
Features implement behavior.
State defines authority.
Apply orchestrates flow.
Platforms prepare execution.

If these boundaries blur,
maintainability degrades.

Architecture must remain minimal, strict, and predictable.

This system is built around five principles:

1. Declaration over scripting
2. State over inference
3. Orchestration over coupling
4. Safety over convenience
5. Replaceability over rigidity

The architecture exists to preserve these principles.

## Purpose

This repository is not a collection of configuration files.

It is a **declarative environment management system**.

Its goals are:

* Reproducibility
* Safety
* Determinism
* Cross-platform consistency
* Long-term maintainability

Architecture exists to enforce boundaries.

## Architectural Model

The system is composed of five layers:

```
platforms  →  profiles  →  apply  →  core  →  features
                               ↓
                             state
```

Each layer has strict responsibility constraints.

Layer violations are considered architectural errors.

## Layer Responsibilities

### platforms/ (Bootstrap Layer)

#### Purpose

Prepare the minimum runtime environment required to execute dotfiles.

#### Responsibilities

* Detect OS
* Set environment variables
* Install minimal dependencies:

  * git
  * jq
  * yq
  * shell environment

#### Must NOT

* Interpret profiles
* Install features
* Modify state
* Resolve dependencies

Bootstrap is execution preparation only.

### profiles/ (Declaration Layer)

#### Purpose

Declare desired environment composition.

Profiles define **intent**, not behavior.

#### Responsibilities

* List enabled features
* Provide optional configuration values

#### Must NOT

* Contain logic
* Contain OS branching
* Contain commands
* Contain install details

Profiles answer only:

> What should be present?

Not:

> How should it be installed?

### apply (Orchestration Layer)

Entry point:

* apply.sh
* apply.ps1

#### Purpose

Coordinate execution flow.

apply must remain a thin orchestration layer internally separated into:

- resolution
- diff computation
- uninstall phase
- install phase

#### Responsibilities

1. Load profile
2. Load state
3. Load feature metadata
4. Resolve dependencies
5. Compute diff (desired vs installed)
6. Execute uninstall → install
7. Commit state

#### Must NOT

* Perform package management directly
* Contain feature-specific logic
* Manipulate JSON directly
* Inspect feature internals

apply is a coordinator.

### core (Infrastructure Layer)

Defined in CORE.md.

#### Purpose

Provide reusable infrastructure primitives.

Core includes:

* Dependency resolver
* State abstraction
* Package abstraction
* Execution utilities

Core must remain:

* Tool-agnostic
* Platform-insulated
* Deterministic

Core does not define environment semantics.

### features/ (Implementation Layer)

#### Purpose

Implement environment units.

One feature = one responsibility.

#### Responsibilities

* Install tool
* Place configuration files
* Register resources in state
* Remove only tracked resources

#### Must NOT

* Resolve dependencies
* Modify other features
* Access state directly
* Perform global destructive actions

Features implement.
They do not orchestrate.

## Data Flow Model

The system follows this deterministic flow:

```
Profile → Desired Features
State → Installed Features
Resolver → Ordered Feature List
Diff → Install / Uninstall Sets
Execution → State Update
```

State is both input and output of execution.

No other layer persists execution memory.

## Dependency Model

Dependencies are declared per feature:

```yaml
depends:
  - git
```

### Rules

* Represents installation prerequisite only
* Used for ordering only
* Must remain shallow
* Cycles are forbidden
* No version constraints
* No conditional dependencies

Dependency resolution is static.

Runtime dependency logic is forbidden.

## State as Authority

State (see STATE_SPEC.md) defines:

* Installed features
* Safe-to-remove resources

No uninstall action may occur without state confirmation.

Filesystem inspection must never replace state.

State is authoritative.

## Safety Guarantees

The architecture guarantees:

* Deterministic dependency order
* Idempotent execution
* No untracked deletion
* Atomic state updates

The architecture does NOT guarantee:

* Transaction rollback
* Package manager consistency
* External system correctness

Safety is bounded by state.

## Platform Abstraction

Platform differences must remain isolated to:

* bootstrap layer
* package abstraction layer

Features may branch minimally using environment variables.

Platform logic must not leak into profiles or state.

## Idempotency Model

Re-running apply must:

* Produce no duplicate resources
* Produce no inconsistent state
* Avoid reinstalling already-present features

Idempotency is enforced via:

* State diff
* Deterministic execution
* Shallow dependencies

## Architectural Constraints (Non-Negotiable Rules)

The following are prohibited:

* Writing to state outside state module
* Direct package manager invocation inside features
* Logic in profiles
* Filesystem scanning during uninstall
* Cross-feature resource ownership
* Deep dependency graphs

Violations require architectural review.

## Extensibility Model

Future changes may include:

* Additional platforms
* Alternative package backends
* Runtime manager changes
* State schema extensions

The architecture must allow:

* Package abstraction replacement
* Feature addition without core modification
* Platform expansion without state change

If extension requires modifying multiple layers simultaneously,
the layering model is being violated.

## Compatibility Expectations

Backward compatibility must preserve:

* State schema validity
* Feature identity
* Dependency semantics
* Install/uninstall symmetry

Breaking changes require:

* State version update
* Documentation update
* Migration guidance
