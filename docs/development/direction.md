# Direction (Under Consideration)

This document describes **possible** future directions. None of these are committed.
They are recorded so that design and contribution decisions can align with long-term thinking.

## Why Document Uncommitted Work?

* **Development** — Avoid over-investing in areas that may be replaced (e.g. deep shell optimizations if Rust is planned).
* **Design** — Keep current specs and architecture valid; direction docs do not override them.
* **Clarity** — Distinguish "current contract" (specs) from "exploration" (this document).

## Directions Under Consideration

### Rust migration

Reimplementing core (resolver, planner, executor, state, backend dispatch) in Rust.

* **Rationale** — Performance, single binary, stronger typing, cross-platform without shell/PowerShell duality.
* **Scope** — Core logic and possibly CLI; features and backends may remain script-based or become pluggable.
* **Status** — Exploratory. No timeline. Current shell/PowerShell implementation remains the reference.

### Externalized profile / policy / feature / backend

Allowing profile, policy, feature definitions, and backends to be loaded from outside the repository (e.g. config directories, plugin paths, remote sources).

* **Rationale** — Users can maintain private profiles or third-party features without forking; separation of "dotfiles engine" vs "my config".
* **Scope** — Load paths, discovery, validation; compatibility with current in-repo layout.
* **Status** — Exploratory. Contract (profile/policy/state schema) would remain; only the source of files would change.

### Declarative features

Supporting features that are fully declared (e.g. YAML or similar) without imperative install/uninstall scripts.

* **Rationale** — Simpler features (e.g. "install this package at this version, link these files"); less script surface; easier validation and plan accuracy.
* **Scope** — New feature format or mode; coexistence with script-based features. May align with "externalized" features (e.g. declarative feature packs).
* **Status** — Exploratory. Current model (meta.yaml + install/uninstall scripts) remains the norm.
