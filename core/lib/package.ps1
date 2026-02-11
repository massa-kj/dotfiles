# Package manager abstraction for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This library expects env.ps1 and logger.ps1 to be loaded by the caller.

function Get-PackageManager {
    <#
    .SYNOPSIS
    Detect available package manager
    #>
    
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

function Test-Package {
    <#
    .SYNOPSIS
    Check if a package is installed
    #>
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
            $installed = & scoop list $Name 2>$null
            return $LASTEXITCODE -eq 0 -and $installed
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

function Install-Package {
    <#
    .SYNOPSIS
    Install a package
    #>
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
                    & scoop bucket add $Bucket 2>&1 | Out-Null
                }
                & scoop install $Name
                if ($LASTEXITCODE -ne 0) {
                    throw "scoop install failed"
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

function Uninstall-Package {
    <#
    .SYNOPSIS
    Uninstall a package
    #>
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
                & scoop uninstall $Name
                if ($LASTEXITCODE -ne 0) {
                    throw "scoop uninstall failed"
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

function Test-Runtime {
    <#
    .SYNOPSIS
    Check if a runtime is installed via mise
    #>
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

function Install-Runtime {
    <#
    .SYNOPSIS
    Install a runtime via mise
    #>
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

function Uninstall-Runtime {
    <#
    .SYNOPSIS
    Uninstall a runtime via mise
    #>
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

# Export functions
Export-ModuleMember -Function Get-PackageManager, Test-Package, Install-Package, Uninstall-Package, Test-Runtime, Install-Runtime, Uninstall-Runtime
