#Requires -Version 5.1

<#
.SYNOPSIS
    Version upgrade scenario - Version change reinstall test

.DESCRIPTION
    Verifies:
    - Version mismatch triggers reinstall
    - Old version is removed before new installation
    - State is updated with new version and package
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$StateFile = "state\state.json"
$ProfileV20 = "C:\temp-profile-v20.yaml"
$ProfileV22 = "C:\temp-profile-v22.yaml"

Write-Host "==> Version upgrade scenario" -ForegroundColor Cyan
Write-Host ""

Write-Host "==> Creating profile with Node 20" -ForegroundColor Green
$ProfileContent = @"
features:
  git: {}
  scoop: {}
  mise: {}
  node:
    version: "20"
"@

New-Item -ItemType Directory -Force -Path (Split-Path $ProfileV20) | Out-Null
$ProfileContent | Set-Content -Path $ProfileV20 -Encoding UTF8

Write-Host "==> First apply (Node 20)" -ForegroundColor Green
.\dotfiles.ps1 apply $ProfileV20

if ($LASTEXITCODE -ne 0) {
    throw "First apply failed"
}

Write-Host ""
Write-Host "==> Verifying Node 20 installed" -ForegroundColor Green
$State1 = Get-Content $StateFile -Raw | ConvertFrom-Json
$NodeVersion1 = $State1.features.node.runtime.version
if ($NodeVersion1 -ne "20") {
    throw "Node version not recorded correctly: $NodeVersion1"
}

Write-Host "    Initial version: $NodeVersion1" -ForegroundColor Gray

Write-Host "==> Verifying node 20 package in state" -ForegroundColor Green
$NodePackage1 = $State1.features.node.packages | Where-Object { $_ -like "node@*" }
if ($NodePackage1 -notmatch "node@20") {
    throw "Node 20 package not registered: $NodePackage1"
}

Write-Host "    Initial package: $NodePackage1" -ForegroundColor Gray

Write-Host ""
Write-Host "==> Creating profile with Node 22 (version change)" -ForegroundColor Green
$ProfileContent = @"
features:
  git: {}
  scoop: {}
  mise: {}
  node:
    version: "22"
"@

$ProfileContent | Set-Content -Path $ProfileV22 -Encoding UTF8

Write-Host "==> Second apply (Node 22 - should trigger reinstall)" -ForegroundColor Green
.\dotfiles.ps1 apply $ProfileV22

if ($LASTEXITCODE -ne 0) {
    throw "Second apply failed"
}

Write-Host ""
Write-Host "==> Verifying Node 22 installed" -ForegroundColor Green
$State2 = Get-Content $StateFile -Raw | ConvertFrom-Json
$NodeVersion2 = $State2.features.node.runtime.version
if ($NodeVersion2 -ne "22") {
    throw "Node version not updated correctly: $NodeVersion2"
}

Write-Host "    Updated version: $NodeVersion2" -ForegroundColor Gray

Write-Host "==> Verifying node 22 package in state" -ForegroundColor Green
$NodePackage2 = $State2.features.node.packages | Where-Object { $_ -like "node@*" }
if ($NodePackage2 -notmatch "node@22") {
    throw "Node 22 package not registered: $NodePackage2"
}

Write-Host "    Updated package: $NodePackage2" -ForegroundColor Gray

Write-Host "==> Verifying version changed from 20 to 22" -ForegroundColor Green
if ($NodeVersion1 -eq $NodeVersion2) {
    throw "Version did not change"
}

Write-Host "    Version change verified: $NodeVersion1 -> $NodeVersion2" -ForegroundColor Gray

Write-Host ""
Write-Host "==> Version upgrade scenario PASSED" -ForegroundColor Green
