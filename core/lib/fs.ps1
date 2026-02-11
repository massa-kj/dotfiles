# File system helpers

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects logger.ps1 and state.ps1 to be loaded by the caller.

function Ensure-Directory {
    <#
    .SYNOPSIS
    Ensure directory exists
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Backup-File {
    <#
    .SYNOPSIS
    Backup existing file if it exists and is not a symlink
    #>
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

function Backup-Directory {
    <#
    .SYNOPSIS
    Backup existing directory if it exists and is not a symlink
    #>
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

function New-FileLink {
    <#
    .SYNOPSIS
    Create symlink for file
    #>
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

function New-DirectoryLink {
    <#
    .SYNOPSIS
    Create symlink for directory
    #>
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

function Copy-ConfigFile {
    <#
    .SYNOPSIS
    Copy configuration file (instead of symlinking)
    #>
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

function Remove-TrackedFiles {
    <#
    .SYNOPSIS
    Remove all files tracked by a feature
    #>
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

function Get-HomePath {
    <#
    .SYNOPSIS
    Get user home directory path
    #>
    return $env:USERPROFILE
}

function Get-ConfigPath {
    <#
    .SYNOPSIS
    Get configuration directory path (AppData/Local or .config equivalent)
    #>
    param(
        [string]$AppName
    )
    
    if ($AppName) {
        return Join-Path $env:LOCALAPPDATA $AppName
    }
    
    return $env:LOCALAPPDATA
}

function Expand-HomeVariables {
    <#
    .SYNOPSIS
    Expand ~/ to actual home path
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if ($Path -match '^~[/\\]') {
        $Path = $Path -replace '^~', $env:USERPROFILE
    }
    
    return $Path
}
