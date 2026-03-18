<#
.SYNOPSIS
    Bootstrap installer for LastWarAutoScreenshot.

.DESCRIPTION
    Self-elevating bootstrap script that imports the LastWarAutoScreenshot module
    and delegates to the Install-LWAS function. Intended as a double-click entry
    point for first-time users who have not yet imported the module.

    If the current session is not elevated, the script re-launches itself via
    'Start-Process pwsh -Verb RunAs' and exits. All arguments (e.g. -Force) and
    common parameters (-Verbose, -Debug, -WhatIf, -ErrorAction, -WarningAction,
    -InformationAction) are forwarded to the elevated process and to Install-LWAS.

.EXAMPLE
    .\Install-LWAS.ps1

    Installs the module; warns and skips if the version is already installed.

.EXAMPLE
    .\Install-LWAS.ps1 -Force

    Overwrites an existing installation of the same version without prompting.

.EXAMPLE
    .\Install-LWAS.ps1 -IncludeTests

    Installs the module and ensures Pester and Spectre.Console.Testing.dll are
    available for running the test suite.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$IncludeTests
)

# Self-elevation: re-launch as Administrator if not already elevated
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $elevateArgs = [System.Collections.Generic.List[string]]::new()
    $elevateArgs.Add("-File `"$PSCommandPath`"")
    if ($Force)                                                    { $elevateArgs.Add('-Force') }
    if ($IncludeTests)                                             { $elevateArgs.Add('-IncludeTests') }
    if ($PSBoundParameters.ContainsKey('Verbose'))                 { $elevateArgs.Add('-Verbose') }
    if ($PSBoundParameters.ContainsKey('Debug'))                   { $elevateArgs.Add('-Debug') }
    if ($PSBoundParameters.ContainsKey('WhatIf'))                  { $elevateArgs.Add('-WhatIf') }
    if ($PSBoundParameters.ContainsKey('ErrorAction'))             { $elevateArgs.Add("-ErrorAction $($PSBoundParameters['ErrorAction'])") }
    if ($PSBoundParameters.ContainsKey('WarningAction'))           { $elevateArgs.Add("-WarningAction $($PSBoundParameters['WarningAction'])") }
    if ($PSBoundParameters.ContainsKey('InformationAction'))       { $elevateArgs.Add("-InformationAction $($PSBoundParameters['InformationAction'])") }
    Start-Process pwsh -Verb RunAs -ArgumentList $elevateArgs
    exit
}

# Resolve the module manifest relative to this script's location
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (Test-Path (Join-Path $root 'powershell-module')) {
    $moduleDir = Join-Path $root 'powershell-module'
}
elseif (Test-Path (Join-Path $root 'LastWarAutoScreenshot')) {
    $moduleDir = Join-Path $root 'LastWarAutoScreenshot'
}
else {
    Write-Error @"
Could not locate the module directory. Expected one of:

  <root>/
  ├── scripts/
  │   └── Install-LWAS.ps1   ← this file
  └── powershell-module/
      └── LastWarAutoScreenshot.psd1

  OR

  <root>/
  ├── scripts/
  │   └── Install-LWAS.ps1   ← this file
  └── LastWarAutoScreenshot/
      └── LastWarAutoScreenshot.psd1

Ensure the zip was extracted with its folder structure intact.
"@
    $null = Read-Host 'Press Enter to close'
    exit 1
}

$manifest = Join-Path $moduleDir 'LastWarAutoScreenshot.psd1'
if (-not (Test-Path $manifest)) {
    Write-Error "Could not locate the module manifest at: $manifest"
    $null = Read-Host 'Press Enter to close'
    exit 1
}

Import-Module $manifest

$installArgs = @{}
if ($Force)        { $installArgs['Force']        = $true }
if ($IncludeTests) { $installArgs['IncludeTests'] = $true }
foreach ($commonParam in 'Verbose', 'Debug', 'WhatIf', 'ErrorAction', 'WarningAction', 'InformationAction') {
    if ($PSBoundParameters.ContainsKey($commonParam)) {
        $installArgs[$commonParam] = $PSBoundParameters[$commonParam]
    }
}
Install-LWAS @installArgs
$null = Read-Host 'Press Enter to close'
