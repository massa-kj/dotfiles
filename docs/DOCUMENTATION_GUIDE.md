# Documentation Guide

This document defines what should be documented where.

The goal is to separate stable design principles from volatile implementation details.

## Principle

### 📘 Documents

Write: **Responsibilities, stability, boundaries, guarantees**

Long-lived content that remains valid across implementation changes.

### 💬 Source Comments

Write: **API signatures, argument specs, return values, error codes**

Short-lived content that changes with implementation.

## What to Document

### ARCHITECTURE.md

**Scope**: Implementation-agnostic, permanent design principles

**Content**:

* Layer responsibilities
* apply execution phases (resolve / diff / uninstall / install)
* State as single source of truth
* Dependency resolution rules
* Breaking change criteria
* Package abstraction rationale

**Do NOT write**:

* Function arguments
* Implementation examples
* Command syntax

**Why**: Design philosophy is long-lived, APIs are short-lived.

### CORE.md

**Scope**: Module boundary level

**Content**:

* Core module structure
* Each module's responsibility
* Public API categories (state / package / resolver)
* API stability level classification
* Breaking change definition

**Example of what to write**:

```
Public API categories:
- Stable API (state, package)
- Internal API (runner, logger)
```

**Do NOT write**:

* Argument order
* Return value format
* Implementation examples

### STATE_SPEC.md

**Scope**: State contract

**Content**:

* JSON schema
* Invariants
* Atomic update requirements
* Versioning policy

**Do NOT write**:

* state_add_file argument specification
* jq command examples

### FEATURE_GUIDE.md

**Scope**: Feature implementation rules

**Content**:

* install/uninstall symmetry
* package abstraction requirement
* executor-owns-state principle
* Prohibited actions

**Do NOT write**:

* Backend function argument specification
* runner return value specification

## Source Comment Specification

Source comments define callable API only.

Documents describe principles.
Source comments describe functions.

Keep comments minimal.

### Module Header

Required:

- Module name
- Stable public API list
- Internal API list (optional)

Format:

```
# -----------------------------------------------------------------------------
# Module: <name>
#
# Responsibility:
#   One-line responsibility.
#
# Public API (Stable):
#   function_name <args>
#
# Public API (Internal):
#   internal_function
# -----------------------------------------------------------------------------
```

Rules:

- No guarantees section.
- No invariants section.
- No stability duplication.
- No implementation detail.
- Only callable surface is defined here.

### Function Comment

Required for Stable APIs only.

Format:

```
# function_name <args>
# Primary one-line description (required).
# Optional: Additional constraint or note (if essential).
```

Rules:

- First line after signature: Concise summary (mandatory)
- Additional lines: Important constraints, preconditions, or behaviors (optional)
- Keep descriptions concise: 1-3 lines recommended for clarity
- Use additional lines only when truly necessary
- No blank lines between signature and description
- No blank lines between description and function definition

## API Stability Levels

Defined in CORE.md.

**Categories**:

### Stable API

* state_*
* resolve_dependencies

→ Used by external code (features, apply)  
→ Changes are breaking

### Internal API

* runner_*
* logger_*
* fs_*

→ Core-internal only  
→ Free to change

### Experimental API

* Unstable APIs

→ Must be marked explicitly as unstable in comments

## What NOT to Document

Do not document in either documents or comments:

* Internal jq implementation details
* Command syntax minutiae
* OS-specific branching logic
* Debug helper functions
* Excessive usage examples
  → Source code is sufficient. Documents should contain principles only.
* Historical implementation rationale
  → Git log is sufficient. Documents should reflect current state only.

**Why**: Implementation freedom should not be constrained.

## Documentation Structure Summary

| Content            | Location           |
| ------------------ | ------------------ |
| Layer boundaries   | ARCHITECTURE       |
| Module responsibilities | CORE          |
| state structure    | STATE_SPEC         |
| feature rules      | FEATURE_GUIDE      |
| API signatures     | Source comments    |
| Argument specs     | Source comments    |
| Return value specs | Source comments    |
| Error codes        | Source comments    |
| Stability classification | CORE        |

## Guidelines for Future Updates

### When Adding a New Feature

1. Implement the feature
2. Add function comments in source
3. Update FEATURE_GUIDE.md **only if** new patterns emerge

### When Changing Core API

1. Check CORE.md for stability level
2. If Stable → requires migration guide
3. Update source comments
4. Do NOT update ARCHITECTURE.md unless design principles change

### When Restructuring Layers

1. Update ARCHITECTURE.md first
2. Implement changes
3. Update CORE.md if module responsibilities shift
4. Source comments change naturally with implementation

## Maintenance Philosophy

**Documents**: Principles that outlive implementations  
**Source comments**: Contracts that change with code

Keep them separate.

Keep them minimal.

Keep them synchronized only at the appropriate abstraction level.
