<#
.SYNOPSIS
    Creates a versioned release zip for LastWarAutoScreenshot.

.DESCRIPTION
    Automates the following steps for a new release:

    1. Validates the supplied version string against semver format.
    2. Resolves the module root (supports both repo layout and zip-extracted layout).
    3. Collects release notes (from parameter or interactive prompt).
    4. Updates 'ModuleVersion' and 'ReleaseNotes' in the psd1 file.
    5. Runs the full Pester test suite (unless -SkipTests is specified).
    6. Assembles a staging directory and compresses it to a release zip.
    7. Prints a post-release checklist.

    The script does NOT perform any git operations. Follow the printed checklist
    to commit the psd1 change, tag the release, push, and upload the zip.

.PARAMETER Version
    Required. The release version in semver format (e.g. '1.2.3').

.PARAMETER OutputDir
    Optional. Directory where the release zip is written.
    Defaults to '<repo root>\releases'.

.PARAMETER ReleaseNotes
    Optional. Release notes text. If omitted, the script prompts interactively.

.PARAMETER SkipTests
    Switch. Skips the Pester test suite run. Intended for dry-run testing of
    this script only — do NOT use this flag for real releases.

.EXAMPLE
    .\New-LWASRelease.ps1 -Version '1.1.0' -ReleaseNotes 'Bug fixes and performance improvements.'

    Updates psd1, runs tests, creates 'releases/LastWarAutoScreenshot-v1.1.0.zip'.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$OutputDir = (Join-Path $PSScriptRoot '..\releases'),

    [string]$ReleaseNotes,

    [switch]$SkipTests
)

# Validate semver
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must be in semver format (e.g. '1.2.3'). Got: $Version"
}

# Resolve paths — support repo layout (powershell-module/) and zip layout (LastWarAutoScreenshot/)
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (Test-Path (Join-Path $repoRoot 'powershell-module')) {
    $moduleRoot = Join-Path $repoRoot 'powershell-module'
}
elseif (Test-Path (Join-Path $repoRoot 'LastWarAutoScreenshot')) {
    $moduleRoot = Join-Path $repoRoot 'LastWarAutoScreenshot'
}
else {
    throw "Could not locate the module root. Expected 'powershell-module' or 'LastWarAutoScreenshot' under '$repoRoot'."
}

# Collect release notes if not supplied
while (-not $ReleaseNotes) {
    $ReleaseNotes = Read-Host "Enter release notes for v$Version"
    if (-not $ReleaseNotes) {
        Write-Warning 'Release notes cannot be empty. Please enter a description.'
    }
}

# Update ModuleVersion and ReleaseNotes in psd1
$psd1Path    = Join-Path $moduleRoot 'LastWarAutoScreenshot.psd1'
$psd1Content = Get-Content $psd1Path -Raw
$psd1Content = $psd1Content -replace "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion = '$Version'"
$psd1Content = $psd1Content -replace "ReleaseNotes\s*=\s*'[^']*'", "ReleaseNotes = 'v$Version — $ReleaseNotes'"
Set-Content -Path $psd1Path -Value $psd1Content -Encoding UTF8 -NoNewline
Write-Output "Updated psd1: ModuleVersion = $Version, ReleaseNotes updated."

# Check if module is installed to PSModulePath; if not and tests required, offer to install
$installedModule = Get-Module -Name 'LastWarAutoScreenshot' -ListAvailable | Select-Object -First 1

if (-not $installedModule -and -not $SkipTests) {
    Write-Warning 'The module is not currently installed to PSModulePath.'
    $installChoice = Read-Host 'Do you want to install the module (with tests) now? Enter "n" to skip testing (y/n)'
    if ($installChoice -match '^(y|yes)$') {
        $installScript = Join-Path $PSScriptRoot 'Install-LWAS.ps1'
        $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            & $installScript -Force -IncludeTests
        }
        else {
            Start-Process pwsh -Verb RunAs -Wait -ArgumentList "-File `"$installScript`" -Force -IncludeTests"
        }
        # Refresh module list after installation
        $installedModule = Get-Module -Name 'LastWarAutoScreenshot' -ListAvailable | Select-Object -First 1
    }
    elseif ($installChoice -match '^(n|no)$') {
        $SkipTests = $true
    }
    else {
        Write-Warning "Invalid response '$installChoice'. Please enter 'y', 'yes', 'n', or 'no'."
        $SkipTests = $true
    }

    if (-not $installedModule -and -not $SkipTests) {
        throw "Module is not installed to PSModulePath and tests are required. Run Install-LWAS.ps1 -IncludeTests first."
    }
}

# Module is installed but Tests folder is absent — reinstall with -IncludeTests automatically
if ($installedModule -and -not $SkipTests) {
    $installedTestsPath = Join-Path $installedModule.ModuleBase 'Tests'
    if (-not (Test-Path $installedTestsPath)) {
        Write-Warning "Module installed at '$($installedModule.ModuleBase)' but Tests folder is missing. Reinstalling with -IncludeTests..."
        $installScript = Join-Path $PSScriptRoot 'Install-LWAS.ps1'
        $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            & $installScript -Force -IncludeTests
        }
        else {
            Start-Process pwsh -Verb RunAs -Wait -ArgumentList "-File `"$installScript`" -Force -IncludeTests"
        }
        $installedModule = Get-Module -Name 'LastWarAutoScreenshot' -ListAvailable | Select-Object -First 1
    }
}

# Run Pester suite unless -SkipTests
if (-not $SkipTests) {
    if (-not $installedModule) {
        throw "Module is not installed. Cannot run tests."
    }

    Remove-Module 'LastWarAutoScreenshot' -Force -ErrorAction SilentlyContinue
    Import-Module 'LastWarAutoScreenshot' -Force -ErrorAction Stop

    $testsPath = Join-Path $installedModule.ModuleBase 'Tests'

    if (-not (Test-Path $testsPath)) {
        throw "Tests not found at '$testsPath'. Run Install-LWAS.ps1 -IncludeTests first."
    }

    $result = Invoke-Pester -Path $testsPath -Output Minimal -PassThru
    if ($result.FailedCount -gt 0 -or $result.Result -ne 'Passed') {
        throw "Pester suite failed ($($result.FailedCount) failure(s)). Release zip not created. Fix all failures before releasing."
    }
    Write-Output "Pester: $($result.PassedCount) tests passed. Suite is green."
}
else {
    Write-Warning '-SkipTests specified — Pester suite was NOT run. Do not use this flag for real releases.'
}

# Create output directory
$OutputDir = (New-Item -Path $OutputDir -ItemType Directory -Force).FullName

# Assemble staging directory and create zip
$stagingRoot = Join-Path $env:TEMP "LWAS_Release_v$Version"
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }

$stagingModuleDir = Join-Path $stagingRoot 'LastWarAutoScreenshot'
New-Item -Path $stagingModuleDir -ItemType Directory -Force | Out-Null

Copy-Item -Path "$moduleRoot\*" -Destination $stagingModuleDir -Recurse -Force
Remove-Item (Join-Path $stagingModuleDir 'Docs')  -Recurse -Force -ErrorAction SilentlyContinue

$scriptsSource = Join-Path $repoRoot 'scripts'
Copy-Item -Path $scriptsSource -Destination (Join-Path $stagingRoot 'scripts') -Recurse -Force

$licenseSource = Join-Path $repoRoot 'LICENSE'
Copy-Item -Path $licenseSource -Destination $stagingRoot -Force

$zipPath = Join-Path $OutputDir "LastWarAutoScreenshot-v$Version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Compress-Archive -Path "$stagingRoot\*" -DestinationPath $zipPath
Remove-Item $stagingRoot -Recurse -Force

Write-Output "Release zip created: $zipPath"

# Post-release checklist
Write-Output ''
Write-Output '=== Post-release checklist ==='
Write-Output "  1. Review and commit psd1 changes: git add powershell-module/LastWarAutoScreenshot.psd1 && git commit -m 'chore(release): bump version to $Version'"
Write-Output "  2. Tag the release:                git tag v$Version"
Write-Output "  3. Push tag and branch:            git push && git push origin v$Version"
Write-Output "  4. Upload release zip to GitHub:   $zipPath"
Write-Output '  5. Create GitHub Release, paste release notes, attach zip.'
Write-Output '==============================='
