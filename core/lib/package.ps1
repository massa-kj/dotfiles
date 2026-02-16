# -----------------------------------------------------------------------------
# Module: package
#
# Responsibility:
#   Provide package manager abstraction for system packages and runtimes.
#
# Public API (Stable):
#   Install-Package <Name> [Manager] [Bucket]
#   Uninstall-Package <Name> [Manager]
#   Install-Runtime <Name> <Version>
#   Uninstall-Runtime <Name> [Version]
#   Get-PackageManager
#   Test-Package <Name> [Manager]
#   Test-Runtime <Name> [Version]
# -----------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1 and logger.ps1 to be loaded by the caller.

# Get-PackageManager
# Detect available package manager on the system.
function Get-PackageManager {
    # Prefer Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return "scoop"
    }
    
    # Fallback to WinGet
    # if (Get-Command winget -ErrorAction SilentlyContinue) {
    #     return "winget"
    # }
    
    Log-Error "No supported package manager found (scoop/winget/choco)"
    throw "No package manager available"
}

# Test-Package <Name> [Manager]
# Check if a package is installed.
function Test-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Manager = $null
    )
    
    if (-not $Manager) {
        $Manager = Get-PackageManager
    }
    
    switch ($Manager) {
        "scoop" {
            $output = & scoop list 2>&1 | Out-String
            return $output -match [regex]::Escape($Name)
        }
        # "winget" {
        #     $result = & winget list --id $Name --exact 2>$null
        #     return $LASTEXITCODE -eq 0 -and $result -match $Name
        # }
        default {
            Log-Error "Unsupported package manager: $Manager"
            throw "Unsupported package manager: $Manager"
        }
    }
}

# Install-Package <Name> [Manager] [Bucket]
# Install a package using specified or detected package manager.
function Install-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Manager = $null,
        [string]$Bucket = $null
    )
    
    if (-not $Manager) {
        $Manager = Get-PackageManager
    }
    
    if (Test-Package -Name $Name -Manager $Manager) {
        Log-Info "Package already installed: $Name"
        return $true
    }
    
    Log-Info "Installing package ($Manager): $Name"
    
    try {
        switch ($Manager) {
            "scoop" {
                if ($Bucket) {
                    Log-Info "Adding bucket: $Bucket"
                    & scoop bucket add $Bucket 2>&1 | ForEach-Object { Write-Host $_ }
                }
                & scoop install $Name 2>&1 | ForEach-Object { Write-Host $_ }
                if ($LASTEXITCODE -ne 0) {
                    throw "scoop install failed with exit code $LASTEXITCODE"
                }
            }
            "winget" {
                & winget install --id $Name --exact --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -ne 0) {
                    throw "winget install failed"
                }
            }
            default {
                throw "Unsupported package manager: $Manager"
            }
        }
        
        Log-Success "Package installed: $Name"
        return $true
    } catch {
        Log-Error "Failed to install package: $Name - $_"
        return $false
    }
}

# Uninstall-Package <Name> [Manager]
# Uninstall a package using specified or detected package manager.
function Uninstall-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Manager = $null
    )
    
    if (-not $Manager) {
        $Manager = Get-PackageManager
    }
    
    if (-not (Test-Package -Name $Name -Manager $Manager)) {
        Log-Info "Package not installed: $Name"
        return $true
    }
    
    Log-Info "Uninstalling package ($Manager): $Name"
    
    try {
        switch ($Manager) {
            "scoop" {
                & scoop uninstall $Name 2>&1 | ForEach-Object { Write-Host $_ }
                if ($LASTEXITCODE -ne 0) {
                    throw "scoop uninstall failed with exit code $LASTEXITCODE"
                }
            }
            "winget" {
                & winget uninstall --id $Name --exact --silent
                if ($LASTEXITCODE -ne 0) {
                    throw "winget uninstall failed"
                }
            }
            default {
                throw "Unsupported package manager: $Manager"
            }
        }
        
        Log-Success "Package uninstalled: $Name"
        return $true
    } catch {
        Log-Error "Failed to uninstall package: $Name - $_"
        return $false
    }
}

# Test-Runtime <Name> [Version]
# Check if a runtime is installed via mise.
function Test-Runtime {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Version = $null
    )
    
    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Log-Error "mise is not available"
        return $false
    }
    
    try {
        if ($Version) {
            & mise where "$Name@$Version" 2>$null | Out-Null
            return $LASTEXITCODE -eq 0
        }
        
        & mise ls --installed $Name 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Install-Runtime <Name> <Version>
# Install a runtime via mise and set as global default.
function Install-Runtime {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Version
    )
    
    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Log-Error "mise is not available"
        return $false
    }
    
    if (Test-Runtime -Name $Name -Version $Version) {
        Log-Info "Runtime already installed: $Name@$Version"
        return $true
    }
    
    Log-Info "Installing runtime: $Name@$Version"
    
    try {
        & mise install "$Name@$Version"
        if ($LASTEXITCODE -ne 0) {
            throw "mise install failed"
        }
        
        Log-Info "Setting global runtime: $Name@$Version"
        & mise use -g "$Name@$Version"
        if ($LASTEXITCODE -ne 0) {
            throw "mise use failed"
        }
        
        Log-Success "Runtime installed: $Name@$Version"
        return $true
    } catch {
        Log-Error "Failed to install runtime: $Name@$Version - $_"
        return $false
    }
}

# Uninstall-Runtime <Name> [Version]
# Uninstall a runtime via mise.
function Uninstall-Runtime {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Version = $null
    )
    
    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Log-Error "mise is not available"
        return $false
    }
    
    $runtimeSpec = if ($Version) { "$Name@$Version" } else { $Name }
    
    if (-not (Test-Runtime -Name $Name -Version $Version)) {
        Log-Info "Runtime not installed: $runtimeSpec"
        return $true
    }
    
    Log-Info "Uninstalling runtime: $runtimeSpec"
    
    try {
        & mise uninstall $runtimeSpec
        if ($LASTEXITCODE -ne 0) {
            throw "mise uninstall failed"
        }
        
        Log-Success "Runtime uninstalled: $runtimeSpec"
        return $true
    } catch {
        Log-Error "Failed to uninstall runtime: $runtimeSpec - $_"
        return $false
    }
}
