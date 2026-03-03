# Core API (Bash)
This document is generated from source comments.
Only **Stable** APIs are listed.

## backend_registry
Resolve, load, and dispatch backend plugin operations.

### Stable APIs
- **`backend_registry_load_policy [policy_file]`**  
  Load policy YAML into memory cache.  
  Uses DOTFILES_POLICY_FILE if no argument is given.  
  Idempotent: calling multiple times with the same file is safe.  
  Non-fatal if the file does not exist – caller falls back to platform defaults.

- `resolve_backend_for <kind> <name>`
- **`load_backend <backend_id>`**  
  Source the backend plugin file and validate the Backend Plugin Contract.  
  Sets the active backend: subsequent backend_call() calls operate on this backend.  
  Idempotent for the same backend_id (re-sourcing is skipped).

- `backend_call <op> <args...>`

## fs
Provide file system operations for feature installation.

### Stable APIs
- **`ensure_dir <path>`**  
  Create directory if it does not exist.

- **`backup_file <target>`**  
  Backup existing file with timestamp if it exists and is not a symlink.

- **`backup_dir <target>`**  
  Backup existing directory with timestamp if it exists and is not a symlink.

- **`link_file <feature> <src> <dst>`**  
  Link a file to dst and register to state.  
  Attempts symbolic link; falls back to copy if not supported.

- **`link_dir <feature> <src> <dst>`**  
  Link a directory to dst and register to state.  
  Attempts symbolic link; falls back to copy if not supported.

- **`remove_tracked_files <feature>`**  
  Remove all files tracked by a feature from state.


## logger
Provide logging functions with color-coded output.

### Stable APIs
- **`log_debug <message>`**  
  Output debug level log message.

- **`log_info <message>`**  
  Output info level log message.

- **`log_success <message>`**  
  Output success level log message.

- **`log_warn <message>`**  
  Output warning level log message.

- **`log_error <message>`**  
  Output error level log message.

- **`log_task <message>`**  
  Output task execution marker for start/end of processing.


## repo
Provide repository-based tool installation utilities.

### Stable APIs
- **`clone_repository <feature> <repo_url> <dest_path>`**  
  Clone a git repository to dest_path, or pull if it already exists.  
  Registers the destination directory to feature state for uninstall tracking.

- **`resolve_tool_path <tool_name>`**  
  Returns the canonical install path for a locally managed tool binary.  
  Output: ~/.local/bin/<tool_name>

- **`is_tool_installed <tool_name>`**  
  Check if a tool exists at the local install path (~/.local/bin/<tool_name>).  
  Returns 0 if installed, 1 otherwise.


## resolver
Resolve feature dependencies and perform topological sorting.

### Stable APIs
- **`resolve_dependencies <desired_features> <output_array>`**  
  Resolve capability dependencies and return topologically sorted feature list.

- **`read_feature_metadata <features>`**  
  Read dependency metadata from meta.yaml files for all features.  
  Populates:  
  _RESOLVER_FEATURE_DEPS  – explicit depends (merged with platform-specific)  
  _RESOLVER_PROVIDES      – capability -> features that provide it  
  _RESOLVER_REQUIRES      – feature -> required capabilities


## runner
Provide command execution utilities and helpers.

### Stable APIs
- **`has_command <cmd>`**  
  Check if a command exists in PATH.

- **`require_command <cmd>`**  
  Ensure a command exists, exit with error if not found.

- **`run_or_die <command...>`**  
  Execute command and exit on failure.

- **`ensure_sudo`**  
  Request sudo privileges if on Linux/WSL platforms.


