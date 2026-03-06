# Usage Guide

## Installation

Clone the repository and run the bootstrap script for your platform.

```sh
# Linux / WSL
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
./platforms/linux/bootstrap.sh   # or platforms/wsl/bootstrap.sh
```

Bootstrap installs the minimum dependencies (git, jq, yq) and sets up the environment.
It does not install any features.

## Bootstrap

Bootstrap prepares the execution environment only.
It does not install features. Run `apply` after bootstrap to install your environment.

## Profiles

Profiles live in `profiles/`. Each profile declares which features should be present
and (optionally) which version.

```yaml
# profiles/linux.yaml
features:
  git: {}
  node:
    version: "22.17.1"
  neovim: {}
```

Edit your profile to add or remove features, or change versions.

See `specs/data/profile.md` for the full schema.

## Plan Command

Preview what would happen without making any changes:

```sh
./dotfiles plan
```

Output shows: features to create, destroy, or replace, plus any blocked features.

The plan command never modifies state.

## Apply Command

Execute the plan and apply changes to your environment:

```sh
./dotfiles apply
```

Apply runs planner → executor → state commit.
Each feature operation is committed atomically.
If a feature fails, execution aborts and state remains unchanged.

## Updating Environment

To install a new feature: add it to your profile, then run `apply`.

To remove a feature: remove it from your profile, then run `apply`.

To change a version: update the `version` field in your profile, then run `apply`.
The feature will be uninstalled and reinstalled at the new version.

## Troubleshooting

**Feature is blocked in plan output**
The feature has an unknown resource kind in state. Check `state/state.json` for the affected feature.

**Dependency not found in profile**
A feature declares `requires` for a capability that no current feature provides.
Add the provider feature (e.g. `brew`, `mise`) to your profile.

**State is corrupt**
If `apply` aborts with a state invariant error, do not modify state manually.
Check the error message for which invariant failed and restore from backup if available.
