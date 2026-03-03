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

## Philosophy

This project prioritizes:

* Safety over convenience
* Determinism over cleverness
* Replaceability over tight coupling
* Clear boundaries over flexibility

The architecture is intentionally strict to preserve long-term maintainability.

## Architectural Model

The system is composed of five layers:

```
platforms  →  profiles  →  dotfiles  →  cmd  →  core  →  features
                                         ↓
                                       state
```

Each layer has strict responsibility constraints.

Layer violations are considered architectural errors.

## Physical Structure

The logical architecture maps to the following directory structure:

```
dotfiles/
├── .dockerignore       # Docker build exclusions (for quality/docker)
├── dotfiles            # Main CLI entry point (Linux/WSL)
├── dotfiles.ps1        # Main CLI entry point (Windows)
├── cmd/                # Orchestration layer commands
│   ├── apply.sh        # Apply command implementation (Linux/WSL)
│   ├── apply.ps1       # Apply command implementation (Windows)
│   ├── plan.sh         # Plan command implementation (Linux/WSL)
│   └── plan.ps1        # Plan command implementation (Windows)
├── core/lib/           # Core libraries (bash & PowerShell)
├── features/           # Self-contained feature modules
│   ├── git/
│   │   ├── meta.yaml             # Dependencies and metadata
│   │   ├── meta.{platform}.yaml  # Platform-specific metadata
│   │   ├── install.sh            # Linux/WSL installer
│   │   ├── install.ps1           # Windows installer
│   │   ├── uninstall.sh          # Linux/WSL uninstaller
│   │   ├── uninstall.ps1         # Windows uninstaller
│   │   └── files/                # Configuration files
│   └── ...
├── platforms/          # Platform-specific bootstrap
│   ├── linux/
│   ├── wsl/
│   └── windows/
├── profiles/           # Declarative environment definitions
│   ├── wsl.yaml
│   └── windows.yaml
├── state/              # Installation state (tracked)
├── docs/               # Documentation and guides
├── quality/            # Quality assurance
│   ├── docker/         # Docker-based integration tests
│   │   ├── Dockerfile
│   │   ├── test.sh
│   │   └── scenarios/
│   └── lint.sh
└── tests/              # Unit and integration tests
```

This structure enforces:

* Layer separation through directory boundaries
* Feature independence through self-contained modules
* Platform abstraction through bootstrap isolation
* State authority through dedicated directory

### Notes on File Placement

**.dockerignore**: Located at repository root due to Docker's requirement that it be at the build context root. Used by `quality/docker/Dockerfile` for integration testing.

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

### cmd/ (Orchestration Layer)

Entry points:

* dotfiles / dotfiles.ps1 (dispatcher)
* cmd/apply.sh / cmd/apply.ps1 (apply implementation)
* cmd/plan.sh / cmd/plan.ps1 (plan implementation)

#### Purpose

Coordinate execution flow.

The orchestration layer consists of:

* **dotfiles**: Thin CLI dispatcher that routes commands
* **cmd/apply**: Calls planner → executor pipeline and commits state changes
* **cmd/plan**: Calls planner only — **MUST NOT execute or modify state**

Each command is a thin shim: argument parsing + single library call.

#### apply Responsibilities

1. Load profile, policy, state
2. Resolve feature graph
3. Run planner → produce plan
4. Run executor → execute plan, commit state

#### plan Responsibilities

1. Load profile, policy, state
2. Resolve feature graph
3. Run planner → produce plan
4. Display plan to user
5. Exit — state MUST remain unchanged

#### Must NOT

* Perform package management directly
* Contain feature-specific logic
* Re-classify operations after planner has decided
* Inspect feature internals

apply is a coordinator. plan is read-only.

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

The system follows this deterministic pipeline:

```
Profile + State + Policy
    ↓
  Resolver  (pure — builds feature DAG, topological sort)
    ↓
  Planner   (pure — diff + classify + decide → Plan JSON)
    ↓
  Executor  (impure — executes actions, commits state)
    ↓
  State
```

**Planner is pure**: given the same inputs it always produces the same Plan.
It MUST NOT modify state or invoke backends.

**Executor is impure**: it calls feature scripts and backend plugins.
It MUST commit state atomically after each successful feature operation.

State is both input (current reality) and output (recorded effects) of execution.
No other layer persists execution memory.

## Dependency Model

Features express dependencies via two complementary mechanisms.

### Concrete dependency (`depends`)

```yaml
depends:
  - git
```

Use when the dependency is on a **specific named feature**.

### Capability dependency (`requires` / `provides`)

```yaml
# consumer
requires:
  - name: package_manager

# provider
provides:
  - name: package_manager
```

Use when a feature needs *any* package manager (or runtime manager),
not a specific one. The resolver finds all providers present in the profile
and injects them as implicit ordering dependencies.

If a required capability has no provider in the profile, `apply` aborts.

### Choosing

| Situation | Use |
|---|---|
| Need a specific named feature first | `depends` |
| Need any package manager | `requires: [{name: package_manager}]` |
| Need any runtime manager | `requires: [{name: runtime_manager}]` |

### Rules (both mechanisms)

* Used for ordering only
* Must remain shallow
* Cycles are forbidden
* No version constraints
* No conditional dependencies

Dependency resolution is static.
Runtime dependency logic is forbidden.

See FEATURE_GUIDE.md for the full list of defined capabilities.

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

## Feature Versioning

Profiles support optional version specification per feature.

### Profile Format

```yaml
features:
  git: {}
  node:
    version: "20"
```

Empty map `{}` is equivalent to no configuration.

### Version-Aware Orchestration

The planner classifies features with version mismatches as `replace`.
The executor uninstalls then reinstalls, producing a clean state transition.

Version handling rules:

* Version is passed to feature scripts via `DOTFILES_FEATURE_CONFIG_VERSION`
* Features interpret version semantics — core does not
* Version is recorded in state as runtime metadata
* Features that do not use versioning ignore `DOTFILES_FEATURE_CONFIG_VERSION`

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
