# Specifications

## Purpose

Specs define normative contracts: what inputs are valid, what outputs are guaranteed,
what invariants must hold. They do not explain rationale or implementation details.

## Spec Categories

**Data specs** — Schemas, semantics, and invariants for persistent data formats.

* `data/profile.md` — Profile schema and feature declaration semantics
* `data/policy.md` — Policy schema and backend resolution rules
* `data/state.md` — State schema, invariants, and commit rules

**API specs** — Interface contracts for pluggable components.

* `api/backend.md` — Backend plugin interface

**Algorithm specs** — Input/output contracts for pure computation modules.

* `algorithms/planner.md` — Planner phases, decision table, plan format
* `algorithms/resolver.md` — Dependency resolution algorithm (draft)

## Stability Expectations

Data specs and algorithm specs are stable.
Changes require a version bump or migration path.

API specs may evolve as new backend capabilities are added,
but existing required operations must remain backward-compatible.

## Reading Order

1. `data/state.md` — understand the authority model first
2. `data/profile.md` — understand input declaration
3. `data/policy.md` — understand backend selection
4. `algorithms/planner.md` — understand how decisions are made
5. `api/backend.md` — understand the execution adapter contract
