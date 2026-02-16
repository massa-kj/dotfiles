# -----------------------------------------------------------------------------
# Module: fs
#
# Responsibility:
#   Provide file system operations for feature installation.
#
# Public API (Stable):
#   Ensure-Directory <Path>
#   Backup-File <Target>
#   Backup-Directory <Target>
#   New-FileLink <Feature> <Source> <Destination>
#   New-DirectoryLink <Feature> <Source> <Destination>
#   Copy-ConfigFile <Feature> <Source> <Destination>
#   Remove-TrackedFiles <Feature>
#   Get-HomePath
#   Get-ConfigPath [AppName]
#   Expand-HomeVariables <Path>
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects logger.ps1 and state.ps1 to be loaded by the caller.

# Ensure-Directory <Path>
# Create directory if it does not exist.
function Ensure-Directory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# Backup-File <Target>
# Backup existing file with timestamp if it exists and is not a symlink.
function Backup-File {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target
    )
    
    if ((Test-Path $Target) -and (-not (Get-Item $Target).LinkType)) {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupPath = "${Target}.backup.${timestamp}"
        
        Log-Warn "Backing up existing $Target to $backupPath"
        Move-Item -Path $Target -Destination $backupPath -Force
    }
}

# Backup-Directory <Target>
# Backup existing directory with timestamp if it exists and is not a symlink.
function Backup-Directory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target
    )
    
    if ((Test-Path $Target) -and (Test-Path $Target -PathType Container)) {
        $item = Get-Item $Target
        if (-not $item.LinkType) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $backupPath = "${Target}.backup.${timestamp}"
            
            Log-Warn "Backing up existing directory $Target to $backupPath"
            Move-Item -Path $Target -Destination $backupPath -Force
        }
    }
}

# New-FileLink <Feature> <Source> <Destination>
# Create symbolic link for file and register to state.
function New-FileLink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [Parameter(Mandatory=$true)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )
    
    if (-not (Test-Path $Source)) {
        Log-Error "Source file not found: $Source"
        return $false
    }
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Destination
    Ensure-Directory -Path $parentDir
    
    # Backup existing file
    Backup-File -Target $Destination
    
    # Create symlink
    try {
        # Remove existing symlink if it points to a different location
        if ((Test-Path $Destination) -and (Get-Item $Destination).LinkType) {
            Remove-Item -Path $Destination -Force
        }
        
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -Force | Out-Null
        State-AddFile -Feature $Feature -File $Destination
        Log-Success "Linked $Destination"
        return $true
    } catch {
        Log-Error "Failed to create symlink: $_"
        return $false
    }
}

# New-DirectoryLink <Feature> <Source> <Destination>
# Create symbolic link for directory and register to state.
function New-DirectoryLink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [Parameter(Mandatory=$true)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )
    
    if (-not (Test-Path $Source -PathType Container)) {
        Log-Error "Source directory not found: $Source"
        return $false
    }
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Destination
    Ensure-Directory -Path $parentDir
    
    # Backup existing directory
    Backup-Directory -Target $Destination
    
    # Create symlink
    try {
        # Remove existing symlink if it exists
        if ((Test-Path $Destination) -and (Get-Item $Destination).LinkType) {
            Remove-Item -Path $Destination -Force
        }
        
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -Force | Out-Null
        State-AddFile -Feature $Feature -File $Destination
        Log-Success "Linked $Destination"
        return $true
    } catch {
        Log-Error "Failed to create directory symlink: $_"
        return $false
    }
}

# Copy-ConfigFile <Feature> <Source> <Destination>
# Copy configuration file instead of symlinking and register to state.
function Copy-ConfigFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [Parameter(Mandatory=$true)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )
    
    if (-not (Test-Path $Source)) {
        Log-Error "Source file not found: $Source"
        return $false
    }
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Destination
    Ensure-Directory -Path $parentDir
    
    # Backup existing file
    Backup-File -Target $Destination
    
    # Copy file
    try {
        Copy-Item -Path $Source -Destination $Destination -Force
        State-AddFile -Feature $Feature -File $Destination
        Log-Success "Copied $Destination"
        return $true
    } catch {
        Log-Error "Failed to copy file: $_"
        return $false
    }
}

# Remove-TrackedFiles <Feature>
# Remove all files tracked by a feature from state.
function Remove-TrackedFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Feature
    )
    
    Log-Info "Removing configuration files..."
    
    $files = State-GetFiles -Feature $Feature
    
    foreach ($file in $files) {
        if (-not $file) { continue }
        
        if (-not (Test-Path $file)) {
            Log-Info "Path does not exist, skipping: $file"
            continue
        }
        
        $item = Get-Item $file
        
        if ($item.LinkType) {
            Log-Info "Removing symlink: $file"
            Remove-Item -Path $file -Force
        } else {
            Log-Warn "Path is not a symlink, skipping: $file"
        }
    }
}

# Get-HomePath
# Get user home directory path.
function Get-HomePath {
    return $env:USERPROFILE
}

# Get-ConfigPath [AppName]
# Get configuration directory path (AppData/Local or .config equivalent).
function Get-ConfigPath {
    param(
        [string]$AppName
    )
    
    if ($AppName) {
        return Join-Path $env:LOCALAPPDATA $AppName
    }
    
    return $env:LOCALAPPDATA
}

# Expand-HomeVariables <Path>
# Expand ~/ to actual home path.
function Expand-HomeVariables {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if ($Path -match '^~[/\\]') {
        $Path = $Path -replace '^~', $env:USERPROFILE
    }
    
    return $Path
}
