<#
.SYNOPSIS
    Uninstalls the LastWarAutoScreenshot module.

.DESCRIPTION
    Performs three removal steps:

    1. Module directory removal — locates all installed copies via
       'Get-Module -ListAvailable' and removes them. Falls back to checking the
       standard user-scope path directly if no copies are found.
    2. Windows Event Log source removal — deletes the 'LastWarAutoScreenshot'
       event log source if it exists.
    3. Config directory removal — optionally removes
       '$env:APPDATA\LastWarAutoScreenshot\' including all config files and
       generated scheduler scripts. When -RemoveAppData is specified the removal
       proceeds without prompting; otherwise the user is prompted.

    Must be run in an elevated (Administrator) PowerShell window. All common
    parameters (-Verbose, -Debug, -WhatIf, -ErrorAction, -WarningAction,
    -InformationAction) are forwarded to the elevated process.

.PARAMETER RemoveAppData
    When specified, removes '$env:APPDATA\LastWarAutoScreenshot\' (including all
    config files and generated scheduler scripts) without prompting.

.EXAMPLE
    .\Uninstall-LWAS.ps1

    Uninstalls the module and event log source; prompts before removing AppData.

.EXAMPLE
    .\Uninstall-LWAS.ps1 -RemoveAppData

    Uninstalls everything including the AppData directory, without prompting.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveAppData
)

# Self-elevation: re-launch as Administrator if not already elevated
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $elevateArgs = [System.Collections.Generic.List[string]]::new()
    $elevateArgs.Add("-File `"$PSCommandPath`"")
    if ($RemoveAppData)                                            { $elevateArgs.Add('-RemoveAppData') }
    if ($PSBoundParameters.ContainsKey('Verbose'))                 { $elevateArgs.Add('-Verbose') }
    if ($PSBoundParameters.ContainsKey('Debug'))                   { $elevateArgs.Add('-Debug') }
    if ($PSBoundParameters.ContainsKey('WhatIf'))                  { $elevateArgs.Add('-WhatIf') }
    if ($PSBoundParameters.ContainsKey('ErrorAction'))             { $elevateArgs.Add("-ErrorAction $($PSBoundParameters['ErrorAction'])") }
    if ($PSBoundParameters.ContainsKey('WarningAction'))           { $elevateArgs.Add("-WarningAction $($PSBoundParameters['WarningAction'])") }
    if ($PSBoundParameters.ContainsKey('InformationAction'))       { $elevateArgs.Add("-InformationAction $($PSBoundParameters['InformationAction'])") }
    Start-Process pwsh -Verb RunAs -ArgumentList $elevateArgs
    exit
}

# Warn if module is currently loaded
if (Get-Module -Name LastWarAutoScreenshot) {
    Write-Warning 'LastWarAutoScreenshot is currently imported in this session. Uninstalling while the module is loaded may leave assemblies in memory. Consider starting a new PowerShell session after uninstallation.'
}

# Locate and remove all installed copies
$installedModules = Get-Module -Name LastWarAutoScreenshot -ListAvailable
if ($installedModules) {
    foreach ($installedModule in $installedModules) {
        if ($PSCmdlet.ShouldProcess($installedModule.ModuleBase, 'Remove module directory')) {
            # Remove lib\test explicitly first — Spectre.Console.Testing.dll is never locked
            # by the module itself, so this succeeds even when the main DLLs are loaded and
            # the full directory removal fails silently.
            $testLibPath = Join-Path $installedModule.ModuleBase 'lib\test'
            if (Test-Path $testLibPath) {
                Remove-Item -Path $testLibPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed test library directory: $testLibPath"
            }
            Remove-Item -Path $installedModule.ModuleBase -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $installedModule.ModuleBase) {
                Write-Warning "Could not fully remove $($installedModule.ModuleBase) — some files may be locked. Start a new PowerShell session and re-run uninstall."
            }
            else {
                Write-Output "Removed: $($installedModule.ModuleBase)"
            }
        }
    }
}
else {
    $fallbackPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\LastWarAutoScreenshot'
    if (Test-Path $fallbackPath) {
        if ($PSCmdlet.ShouldProcess($fallbackPath, 'Remove module directory')) {
            # Remove lib\test across all version subdirectories first
            Get-ChildItem -Path $fallbackPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $testLibPath = Join-Path $_.FullName 'lib\test'
                if (Test-Path $testLibPath) {
                    Remove-Item -Path $testLibPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Verbose "Removed test library directory: $testLibPath"
                }
            }
            Remove-Item -Path $fallbackPath -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $fallbackPath) {
                Write-Warning "Could not fully remove $fallbackPath — some files may be locked. Start a new PowerShell session and re-run uninstall."
            }
            else {
                Write-Output "Removed: $fallbackPath"
            }
        }
    }
    else {
        Write-Output 'Module not found in PSModulePath. Skipping module removal.'
    }
}

# Remove Windows Event Log source
try {
    if ([System.Diagnostics.EventLog]::SourceExists('LastWarAutoScreenshot')) {
        try {
            if ($PSCmdlet.ShouldProcess('LastWarAutoScreenshot', 'Delete Windows Event Log source')) {
                [System.Diagnostics.EventLog]::DeleteEventSource('LastWarAutoScreenshot')
                Write-Output 'Windows Event Log source removed.'
            }
        }
        catch {
            Write-Warning "Could not remove Windows Event Log source: $($_.Exception.Message)"
        }
    }
    else {
        Write-Output 'Windows Event Log source not found, skipping.'
    }
}
catch {
    Write-Warning "Could not check Windows Event Log source: $($_.Exception.Message)"
}

# Handle AppData directory removal
$appDataPath = Join-Path $env:APPDATA 'LastWarAutoScreenshot'
if (-not (Test-Path $appDataPath)) {
    Write-Output 'LastWarAutoScreenshot user directory not found, skipping.'
}
else {
    $shouldRemove = $false
    if ($RemoveAppData) {
        $shouldRemove = $true
    }
    else {
        $answer = Read-Host "Remove config, macro, upload profile, and scheduler files at $appDataPath? [Y/N]"
        if ($answer -match '^(y|yes)$') {
            $shouldRemove = $true
        }
    }

    if ($shouldRemove) {
        if ($PSCmdlet.ShouldProcess($appDataPath, 'Remove LastWarAutoScreenshot user directory')) {
            try {
                Remove-Item -Path $appDataPath -Recurse -Force
                Write-Output "Removed LastWarAutoScreenshot user directory: $appDataPath"
            }
            catch {
                Write-Warning "Could not remove LastWarAutoScreenshot user directory: $($_.Exception.Message)"
            }
        }
    }
}

# Completion summary
Write-Output ''
Write-Output 'Uninstallation complete.'
Write-Output 'Start a new PowerShell session to ensure no module assemblies remain in memory.'
$null = Read-Host 'Press Enter to close'
