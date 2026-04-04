function Test-IsAdministrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DotNetRuntimes {
    return & dotnet --list-runtimes 2>&1
}

function Invoke-WingetInstall {
    param([string]$PackageId)
    & winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements
}

function Install-LWAS {
    <#
    .SYNOPSIS
        Installs the LastWarAutoScreenshot module and its dependencies.

    .DESCRIPTION
        Performs the following steps in order:

        1. Admin check — aborts if the session is not elevated.
        2. .NET 9.0 runtime check — offers to install via winget if missing.
        3. Module copy — copies the module to the user-scope PowerShell modules
           directory at '$HOME\Documents\PowerShell\Modules\LastWarAutoScreenshot\{version}\'.
           If an installation already exists at that path, warns and skips unless
           -Force is specified.
        4. Windows Event Log source registration — pre-registers the
           'LastWarAutoScreenshot' source so subsequent log writes do not require
           elevation.
        5. Config directory creation — ensures '$env:APPDATA\LastWarAutoScreenshot\'
           exists.
        6. Macros directory creation — ensures '$env:APPDATA\LastWarAutoScreenshot\Macros\'
           exists.
        7. Config file creation — writes a default ModuleConfig.jsonc to
           '$env:APPDATA\LastWarAutoScreenshot\' if it does not exist.  If a file
           already exists the user is prompted before overwriting (default: no);
           -Force skips the prompt.  In either case the existing file is renamed to
           'moduleconfig_<ddMMyyHHmmss>.bak' before the new default is written.
        8. Dependency verification — checks that the bundled Spectre.Console DLLs
           are present. Downloads from NuGet as a repair step if either is missing.
        9. Test dependencies (when -IncludeTests) — ensures Pester is installed and
           that Spectre.Console.Testing.dll is present in the installed module.

        Must be run in an elevated (Administrator) PowerShell window.

    .PARAMETER Force
        When specified, overwrites an existing installation of the same version
        without prompting.

    .PARAMETER IncludeTests
        When specified, retains the lib\test directory in the installed module and
        ensures Pester and Spectre.Console.Testing.dll are available for running
        the test suite.

    .EXAMPLE
        Install-LWAS

        Installs the module; warns and skips if the version is already installed.

    .EXAMPLE
        Install-LWAS -Force

        Overwrites an existing installation of the same version without prompting.

    .EXAMPLE
        Install-LWAS -IncludeTests

        Installs the module and ensures Pester and Spectre.Console.Testing.dll are
        available for running the test suite.

    .OUTPUTS
        None. Writes progress via Write-Host; operational detail via Write-Verbose.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$IncludeTests
    )

    # Step 1 — Admin check
    if (-not (Test-IsAdministrator)) {
        Write-Warning 'This function must be run in an elevated (Administrator) PowerShell window.'
        Write-Warning 'Please close this window, open PowerShell as Administrator, and run Install-LWAS again.'
        return
    }

    # Step 2 — Check .NET 9.0
    Write-Verbose 'Checking for .NET 9.0 runtime...'
    $runtimes = Get-DotNetRuntimes
    $hasNet9  = ($runtimes | Where-Object { $_ -match 'Microsoft\.NETCore\.App 9\.' }).Count -gt 0

    # Step 3 — Prompt & install .NET 9.0 (if missing)
    if (-not $hasNet9) {
        Write-Warning '.NET 9.0 runtime was not found.'
        $answer = Read-Host 'Install it now via winget? [Y/N]'
        if ($answer -notmatch '^[Yy]') {
            Write-Host 'Installation cancelled. Please install .NET 9.0 manually and re-run Install-LWAS.'
            return
        }
        Write-Host 'Installing .NET 9.0 runtime...'
        Invoke-WingetInstall -PackageId 'Microsoft.DotNet.Runtime.9'

        $runtimes = Get-DotNetRuntimes
        $hasNet9  = ($runtimes | Where-Object { $_ -match 'Microsoft\.NETCore\.App 9\.' }).Count -gt 0
        if (-not $hasNet9) {
            Write-Error '.NET 9.0 installation could not be verified. Please install it manually from https://dotnet.microsoft.com/download/dotnet/9.0 then re-run Install-LWAS.'
            return
        }
        Write-Host '.NET 9.0 installed successfully.'
    }
    else {
        Write-Verbose '.NET 9.0 runtime found.'
    }

    # Step 4 — Copy module to PSModulePath
    $moduleRoot  = Split-Path -Parent $PSScriptRoot
    $psd1Path    = Join-Path $moduleRoot 'LastWarAutoScreenshot.psd1'
    $version     = (Import-PowerShellDataFile $psd1Path).ModuleVersion
    $installBase = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\LastWarAutoScreenshot'
    $installPath = Join-Path $installBase $version

    $skipModuleCopy = $false
    if (Test-Path $installPath) {
        if (-not $Force) {
            Write-Warning "Version $version is already installed at '$installPath'. Use -Force to overwrite."
            $skipModuleCopy = $true
        }
        else {
            Write-Verbose "Version $version already installed — overwriting as requested (-Force)."
            try {
                Remove-Item -Path $installPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not remove existing installation at '$installPath' — some files may be locked (e.g. the module is loaded in VS Code or another terminal). Close all sessions that have the module loaded and try again. Error: $($_.Exception.Message)"
                return
            }
        }
    }

    if (-not $skipModuleCopy) {
        try {
            New-Item -Path $installPath -ItemType Directory -Force | Out-Null
            Copy-Item -Path "$moduleRoot\*" -Destination $installPath -Recurse -Force -ErrorAction Stop
            Remove-Item -Path (Join-Path $installPath 'Docs')  -Recurse -Force -ErrorAction SilentlyContinue
            if (-not $IncludeTests) {
                Remove-Item -Path (Join-Path $installPath 'Tests')    -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path (Join-Path $installPath 'lib\test') -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Module installed to $installPath"
        }
        catch {
            Write-Error $_.Exception.Message
            return
        }
    }

    # Step 5 — Register Windows Event Log source
    $sourceExists = Test-EventLogSourceExists -Source 'LastWarAutoScreenshot'
    if (-not $sourceExists) {
        try {
            Add-EventLogSource -Source 'LastWarAutoScreenshot' -LogName 'Application'
            Write-Verbose 'Windows Event Log source registered.'
        }
        catch {
            Write-Warning "Windows Event Log source could not be registered. Log writes will use the fallback lazy registration. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Verbose 'Windows Event Log source already registered, skipping.'
    }

    # Step 6 — Create AppData config directory
    $appDataPath = Join-Path $env:APPDATA 'LastWarAutoScreenshot'
    if (-not (Test-Path $appDataPath)) {
        New-Item -Path $appDataPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created config directory: $appDataPath"
    }
    else {
        Write-Verbose 'Config directory already exists, skipping.'
    }

    # Step 7 — Create AppData Macros directory
    $macrosPath = Join-Path $appDataPath 'Macros'
    if (-not (Test-Path $macrosPath)) {
        New-Item -Path $macrosPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created macros directory: $macrosPath"
    }
    else {
        Write-Verbose 'Macros directory already exists, skipping.'
    }

    # Step 8 — Create AppData UploadProfiles directory
    $uploadProfilesPath = Join-Path $appDataPath 'UploadProfiles'
    if (-not (Test-Path -Path $uploadProfilesPath -PathType Container)) {
        New-Item -Path $uploadProfilesPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created upload profiles directory: $uploadProfilesPath"
    }
    else {
        Write-Verbose 'Upload profiles directory already exists, skipping.'
    }

    # Step 9 — Create default ModuleConfig.jsonc
    $configPath   = Join-Path $appDataPath 'ModuleConfig.jsonc'
    $configExists = Test-Path -Path $configPath -PathType Leaf

    $writeConfig = $false
    if (-not $configExists) {
        $writeConfig = $true
        Write-Verbose 'No existing config file found; writing defaults.'
    }
    elseif ($Force) {
        $writeConfig = $true
        Write-Verbose 'Config file exists — overwriting as requested (-Force).'
    }
    else {
        $answer = Read-Host "A config file already exists at '$configPath'. Overwrite with defaults? [y/N]"
        if ($answer -match '^[Yy]$') {
            $writeConfig = $true
        }
        else {
            Write-Verbose 'Config file overwrite skipped by user.'
        }
    }

    if ($writeConfig -and $configExists) {
        $timestamp  = Get-Date -Format 'ddMMyyHHmmss'
        $backupName = "moduleconfig_$timestamp.bak"
        $backupPath = Join-Path $appDataPath $backupName
        Move-Item -Path $configPath -Destination $backupPath -Force
        Write-Host "Existing config backed up to: $backupPath"
    }

    if ($writeConfig) {
        $defaults      = Get-DefaultModuleSettings
        $defaultConfig = [PSCustomObject]@{
            Logging        = $defaults.Logging
            MouseControl   = $defaults.MouseControl
            EmergencyStop  = $defaults.EmergencyStop
            Screenshots    = $defaults.Screenshots
            CodeEditor     = $defaults.CodeEditor
            MacroExecution = $defaults.MacroExecution
        }
        $jsonContent = Get-ModuleConfigJsoncContent -Config $defaultConfig
        Set-Content -Path $configPath -Value $jsonContent -Encoding UTF8 -Force
        Write-Host "Default config written to: $configPath"
    }

    # --- Dependency verification ---
    Write-Verbose '--- Dependency verification ---'

    $libPath   = Join-Path $moduleRoot 'lib'
    $dllTarget = Join-Path $libPath 'Spectre.Console.dll'

    if (Test-Path $dllTarget) {
        Write-Verbose 'Spectre.Console.dll already present, skipping download.'
    }
    else {
        $spectreVersion = '0.54.0'
        $nugetUrl       = "https://www.nuget.org/api/v2/package/Spectre.Console/$spectreVersion"
        $nupkgPath      = Join-Path $env:TEMP "Spectre.Console.$spectreVersion.nupkg"
        $extractDir     = Join-Path $env:TEMP "Spectre.Console.$spectreVersion"

        Write-Host 'Spectre.Console.dll missing — downloading from NuGet as repair step...'
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath -UseBasicParsing

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $nupkgPath -DestinationPath $extractDir

        $tfmPreference = @('net9.0', 'net8.0', 'netstandard2.0')
        $dllSource = $null
        foreach ($tfm in $tfmPreference) {
            $candidate = Join-Path $extractDir "lib\$tfm\Spectre.Console.dll"
            if (Test-Path $candidate) { $dllSource = $candidate; break }
        }
        if (-not $dllSource) {
            Write-Error 'Could not locate Spectre.Console.dll inside the downloaded package. Please install manually.'
            return
        }

        Copy-Item -Path $dllSource -Destination $dllTarget -Force
        Write-Host "Spectre.Console $spectreVersion installed to $dllTarget"
    }

    # Step 7 — Test dependencies (only when -IncludeTests)
    if ($IncludeTests) {
        Write-Verbose '--- Test dependency verification ---'

        # Ensure Spectre.Console.Testing.dll is present in the installed module
        $installedTestLibPath = Join-Path $installPath 'lib\test'
        $installedTestingDll  = Join-Path $installedTestLibPath 'Spectre.Console.Testing.dll'

        if (Test-Path $installedTestingDll) {
            Write-Verbose 'Spectre.Console.Testing.dll present in installed module.'
        }
        else {
            # Source may have it already; if so, copy across — otherwise download
            $sourceTestingDll = Join-Path $libPath 'test\Spectre.Console.Testing.dll'
            if (Test-Path $sourceTestingDll) {
                if (-not (Test-Path $installedTestLibPath)) {
                    New-Item -Path $installedTestLibPath -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $sourceTestingDll -Destination $installedTestingDll -Force
                Write-Host "Spectre.Console.Testing.dll copied to installed module."
            }
            else {
                $spectreVersion   = '0.54.0'
                $nugetUrl         = "https://www.nuget.org/api/v2/package/Spectre.Console.Testing/$spectreVersion"
                $nupkgPath        = Join-Path $env:TEMP "Spectre.Console.Testing.$spectreVersion.nupkg"
                $extractDir       = Join-Path $env:TEMP "Spectre.Console.Testing.$spectreVersion"

                Write-Host 'Spectre.Console.Testing.dll missing — downloading from NuGet...'
                Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath -UseBasicParsing

                if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
                Expand-Archive -Path $nupkgPath -DestinationPath $extractDir

                $tfmPreference    = @('net9.0', 'net8.0', 'netstandard2.0')
                $testingDllSource = $null
                foreach ($tfm in $tfmPreference) {
                    $candidate = Join-Path $extractDir "lib\$tfm\Spectre.Console.Testing.dll"
                    if (Test-Path $candidate) { $testingDllSource = $candidate; break }
                }
                if (-not $testingDllSource) {
                    Write-Error 'Could not locate Spectre.Console.Testing.dll inside the downloaded package. Please install manually.'
                    return
                }

                if (-not (Test-Path $installedTestLibPath)) {
                    New-Item -Path $installedTestLibPath -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $testingDllSource -Destination $installedTestingDll -Force
                Write-Host "Spectre.Console.Testing $spectreVersion installed to $installedTestingDll"
            }
        }

        # Ensure Pester is available
        $pester = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if ($pester) {
            Write-Verbose "Pester $($pester.Version) found."
        }
        else {
            Write-Host 'Pester not found — installing from PSGallery...'
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope AllUsers
            $pester = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            if ($pester) {
                Write-Host "Pester $($pester.Version) installed."
            }
            else {
                Write-Warning 'Pester installation could not be verified. Please install it manually: Install-Module Pester'
            }
        }
    }

    # Step 8 — Success message
    Write-Host ''
    Write-Host 'Installation complete.'
    Write-Host "  Module path : $installPath"
    Write-Host "  Config path : $appDataPath"
    if ($IncludeTests) {
        Write-Host "  Test libs   : $(Join-Path $installPath 'lib\test')"
    }
    Write-Host ''
    Write-Host 'You can now use: Import-Module LastWarAutoScreenshot'
}
