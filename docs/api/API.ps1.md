# Core API (PowerShell)
This document is generated from source comments.
Only **Stable** APIs are listed.

## backend_registry
Resolve, load, and dispatch backend plugin operations.

### Stable APIs
- **`Backend-Registry-LoadPolicy [PolicyFile]`**  
  Load policy YAML into memory cache.  
  Uses DOTFILES_POLICY_FILE if no argument is given.

- **`Resolve-BackendFor <Kind> <Name>`**  
  Return the backend_id for the given kind/name pair.  
  Resolution order:  
  1. Policy overrides: .<kind>.overrides.<name>.backend  (resource name, not feature name)  
  2. Policy default:   .<kind>.default_backend  
  3. Platform default (hardcoded)

- **`Load-Backend <BackendId>`**  
  Dot-source the backend plugin file and validate the Backend Plugin Contract.

- `Backend-Call <Op> <Args...>`

## fs
Provide file system operations for feature installation.

### Stable APIs
- **`Ensure-Directory <Path>`**  
  Create directory if it does not exist.

- **`Backup-File <Target>`**  
  Backup existing file with timestamp if it exists and is not a symlink.

- **`Backup-Directory <Target>`**  
  Backup existing directory with timestamp if it exists and is not a symlink.

- **`New-FileLink <Feature> <Source> <Destination>`**  
  Link or copy a file to destination and register to state.  
  Attempts symbolic link first; falls back to copy if not supported.

- **`New-DirectoryLink <Feature> <Source> <Destination>`**  
  Link or copy a directory to destination and register to state.  
  Attempts symbolic link, then junction, then falls back to copy.

- **`Remove-TrackedFiles <Feature>`**  
  Remove all files tracked by a feature from state.

- **`Get-HomePath`**  
  Get user home directory path.

- **`Get-ConfigPath [AppName]`**  
  Get configuration directory path (AppData/Local or .config equivalent).

- **`Expand-HomeVariables <Path>`**  
  Expand ~/ to actual home path.


## logger
Provide logging functions with color-coded output.

### Stable APIs
- **`Log-Debug <Message>`**  
  Output debug level log message.

- **`Log-Info <Message>`**  
  Output info level log message.

- **`Log-Success <Message>`**  
  Output success level log message.

- **`Log-Warn <Message>`**  
  Output warning level log message.

- **`Log-Error <Message>`**  
  Output error level log message.

- **`Log-Task <Message>`**  
  Output task execution marker for start/end of processing.


## repo
Provide repository-based tool installation utilities.

### Stable APIs
- **`Clone-Repository <Feature> <RepoUrl> <DestPath>`**  
  Clone a git repository to DestPath, or pull if it already exists.  
  Registers the destination directory to feature state for uninstall tracking.

- **`Resolve-ToolPath <ToolName>`**  
  Returns the canonical install path for a locally managed tool binary.  
  Output: $env:USERPROFILE\.local\bin\<ToolName>

- **`Test-ToolInstalled <ToolName>`**  
  Check if a tool exists at the local install path (~\.local\bin\<ToolName>).  
  Returns $true if installed, $false otherwise.


## resolver
Resolve feature dependencies and perform topological sorting.

### Stable APIs
- **`Resolve-Dependencies <DesiredFeatures>`**  
  Resolve capability dependencies and return topologically sorted feature list.

- **`Read-FeatureMetadata <Features>`**  
  Read dependency metadata from meta.yaml files for all features.  
  Populates FeatureDeps, Provides, and Requires module-globals.

- **`Invoke-TopoSortDFS <Feature> <DesiredFeatures>`**  
  Perform depth-first search for topological sorting.


## runner
Provide command execution utilities and helpers.

### Stable APIs
- **`Test-Command <Command>`**  
  Check if a command exists in PATH.

- **`Assert-Command <Command>`**  
  Ensure a command exists, throw exception if not found.

- **`Invoke-OrDie <ScriptBlock> [Description]`**  
  Execute command and throw exception on failure.

- **`Test-Administrator`**  
  Check if running with administrator privileges.

- **`Assert-Administrator`**  
  Ensure administrator privileges, throw exception if not running as admin.

- **`Invoke-WithRetry <ScriptBlock> [MaxAttempts] [DelaySeconds]`**  
  Execute command with automatic retry logic on failure.

- **`Get-UserConfirmation <Message> [DefaultYes]`**  
  Prompt user for yes/no confirmation and return boolean result.


