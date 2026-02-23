# Core API (Bash)
This document is generated from source comments.
Only **Stable** APIs are listed.

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


## package
Provide package manager abstraction for system packages and runtimes.

### Stable APIs
- **`install_package <name>`**  
  Install a package using detected package manager.

- **`remove_package <name>`**  
  Remove a package using detected package manager.

- **`install_runtime <name> <version>`**  
  Install a runtime via mise and set as global default.

- **`remove_runtime <name> [version]`**  
  Remove a runtime via mise.

- **`has_package <name>`**  
  Check if a package is installed.

- **`has_runtime <name> [version]`**  
  Check if a runtime is installed via mise.


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
  Resolve dependencies and return topologically sorted feature list.

- **`read_feature_metadata <features>`**  
  Read dependency metadata from meta.yaml files for all features.


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


## state
Manage state file operations safely with atomic updates.

### Stable APIs
- **`state_init`**  
  Initialize or validate state file.

- **`state_has_feature <feature>`**  
  Check if a feature exists in state.

- **`state_add_package <feature> <package>`**  
  Register a package for a feature with deduplication.

- **`state_add_file <feature> <path>`**  
  Register a file path for a feature with deduplication.

- **`state_get_packages <feature>`**  
  Retrieve package list for a feature (one per line).

- **`state_get_files <feature>`**  
  Retrieve file path list for a feature (one per line).

- **`state_has_file <path>`**  
  Check if a file path is registered under any feature.

- **`state_remove_feature <feature>`**  
  Remove a feature entry from state.

- **`state_list_features`**  
  Retrieve all installed feature names (one per line).

- **`state_set_runtime <feature> <key> <value>`**  
  Set runtime metadata for a feature.

- **`state_get_runtime <feature> <key>`**  
  Get runtime metadata for a feature.

- **`state_has_runtime <feature> <key>`**  
  Check if runtime metadata exists for a feature.


