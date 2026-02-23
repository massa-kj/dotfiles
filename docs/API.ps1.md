# Core API (PowerShell)
This document is generated from source comments.
Only **Stable** APIs are listed.

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


## package
Provide package manager abstraction for system packages and runtimes.

### Stable APIs
- **`Install-Package <Name> [Manager] [Bucket]`**  
  Install a package using specified or detected package manager.

- **`Uninstall-Package <Name> [Manager]`**  
  Uninstall a package using specified or detected package manager.

- **`Install-Runtime <Name> <Version>`**  
  Install a runtime via mise and set as global default.

- **`Uninstall-Runtime <Name> [Version]`**  
  Uninstall a runtime via mise.

- **`Get-PackageManager`**  
  Detect available package manager on the system.

- **`Test-Package <Name> [Manager]`**  
  Check if a package is installed.

- **`Test-Runtime <Name> [Version]`**  
  Check if a runtime is installed via mise.


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
  Resolve dependencies and return topologically sorted feature list.

- **`Read-FeatureMetadata <Features>`**  
  Read dependency metadata from meta.yaml files for all features.

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


## state
Manage state file operations safely with atomic updates.

### Stable APIs
- **`State-Init`**  
  Initialize or validate state file.

- **`State-HasFeature <Feature>`**  
  Check if a feature exists in state.

- **`State-AddPackage <Feature> <Package>`**  
  Register a package for a feature with deduplication.

- **`State-AddFile <Feature> <File>`**  
  Register a file path for a feature with deduplication.

- **`State-GetPackages <Feature>`**  
  Retrieve package list for a feature.

- **`State-GetFiles <Feature>`**  
  Retrieve file path list for a feature.

- **`State-HasFile <File>`**  
  Check if a file path is registered under any feature.

- **`State-RemoveFeature <Feature>`**  
  Remove a feature entry from state.

- **`State-ListFeatures`**  
  Retrieve all installed feature names.

- **`State-SetRuntime <Feature> <Key> <Value>`**  
  Set runtime metadata for a feature.

- **`State-GetRuntime <Feature> <Key>`**  
  Get runtime metadata for a feature.

- **`State-HasRuntime <Feature> <Key>`**  
  Check if runtime metadata exists for a feature.


