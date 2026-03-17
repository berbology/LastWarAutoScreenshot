function Install-LWASModule {
    <#
    .SYNOPSIS
        Installs the runtime dependencies required by LastWarAutoScreenshot.

    .DESCRIPTION
        Validates and installs the runtime dependencies that must be present
        before Import-Module succeeds: the .NET 9.0 runtime, Spectre.Console 0.54.0,
        and Spectre.Console.Testing 0.54.0 (required by the test suite).

        Must be run in an elevated (Administrator) PowerShell window.

    .EXAMPLE
        Install-LWASModule

        Runs the interactive installer, checking for and installing missing dependencies.

    .OUTPUTS
        None. Writes progress to the output stream.
    #>
    [CmdletBinding()]
    param()

    # Step 1 — Admin check
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning 'This function must be run in an elevated (Administrator) PowerShell window.'
        Write-Output  'Please close this window, open PowerShell as Administrator, and run Install-LWASModule again.'
        return
    }

    # Step 2 — Check .NET 9.0
    Write-Output 'Checking for .NET 9.0 runtime...'
    $runtimes = & dotnet --list-runtimes 2>&1
    $hasNet9  = ($runtimes | Where-Object { $_ -match 'Microsoft\.NETCore\.App 9\.' }).Count -gt 0

    # Step 3 — Prompt & install .NET 9.0 (if missing)
    if (-not $hasNet9) {
        Write-Output '  .NET 9.0 runtime was not found.'
        $answer = Read-Host '  Install it now via winget? [Y/N]'
        if ($answer -notmatch '^[Yy]') {
            Write-Output 'Installation cancelled. Please install .NET 9.0 manually and re-run Install-LWASModule.'
            return
        }
        Write-Output 'Installing .NET 9.0 runtime...'
        & winget install --id Microsoft.DotNet.Runtime.9 --silent --accept-package-agreements --accept-source-agreements

        $runtimes = & dotnet --list-runtimes 2>&1
        $hasNet9  = ($runtimes | Where-Object { $_ -match 'Microsoft\.NETCore\.App 9\.' }).Count -gt 0
        if (-not $hasNet9) {
            Write-Error '.NET 9.0 installation could not be verified. Please install it manually from https://dotnet.microsoft.com/download/dotnet/9.0 then re-run Install-LWASModule.'
            return
        }
        Write-Output '.NET 9.0 installed successfully.'
    }
    else {
        Write-Output '  .NET 9.0 runtime found.'
    }

    # Step 4 — Install Spectre.Console 0.54.0
    $libPath   = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
    $dllTarget = Join-Path $libPath 'Spectre.Console.dll'

    if (Test-Path $dllTarget) {
        Write-Output 'Spectre.Console.dll already present, skipping download.'
    }
    else {
        $version    = '0.54.0'
        $nugetUrl   = "https://www.nuget.org/api/v2/package/Spectre.Console/$version"
        $nupkgPath  = Join-Path $env:TEMP "Spectre.Console.$version.nupkg"
        $extractDir = Join-Path $env:TEMP "Spectre.Console.$version"

        Write-Output "Downloading Spectre.Console $version from NuGet..."
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
        Write-Output "Spectre.Console $version installed to $dllTarget"
    }

    # Step 5 — Install Spectre.Console.Testing 0.54.0
    $testLibPath         = Join-Path $libPath 'test'
    $testingDllTarget    = Join-Path $testLibPath 'Spectre.Console.Testing.dll'

    if (Test-Path $testingDllTarget) {
        Write-Output 'Spectre.Console.Testing.dll already present, skipping download.'
    }
    else {
        $version    = '0.54.0'
        $nugetUrl   = "https://www.nuget.org/api/v2/package/Spectre.Console.Testing/$version"
        $nupkgPath  = Join-Path $env:TEMP "Spectre.Console.Testing.$version.nupkg"
        $extractDir = Join-Path $env:TEMP "Spectre.Console.Testing.$version"

        Write-Output "Downloading Spectre.Console.Testing $version from NuGet..."
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath -UseBasicParsing

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $nupkgPath -DestinationPath $extractDir

        $tfmPreference = @('net9.0', 'net8.0', 'netstandard2.0')
        $testingDllSource = $null
        foreach ($tfm in $tfmPreference) {
            $candidate = Join-Path $extractDir "lib\$tfm\Spectre.Console.Testing.dll"
            if (Test-Path $candidate) { $testingDllSource = $candidate; break }
        }
        if (-not $testingDllSource) {
            Write-Error 'Could not locate Spectre.Console.Testing.dll inside the downloaded package. Please install manually.'
            return
        }

        if (-not (Test-Path $testLibPath)) { New-Item -Path $testLibPath -ItemType Directory | Out-Null }
        Copy-Item -Path $testingDllSource -Destination $testingDllTarget -Force
        Write-Output "Spectre.Console.Testing $version installed to $testingDllTarget"
    }

    # Step 6 — Success message
    Write-Output ''
    Write-Output 'Installation complete. All dependencies are ready.'
    Read-Host 'Press Enter to continue'
}
