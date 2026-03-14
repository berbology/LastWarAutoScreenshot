# Robust C# type loader: check file existence, abort if missing, check for loaded types, abort if loaded, else Add-Type

$logBackendSourcecodePath = "$PSScriptRoot\src\LogBackend.cs"
$fileLogBackendSourcecodePath = "$PSScriptRoot\src\FileLogBackend.cs"
$windowEnumerationAPISourcecodePath = "$PSScriptRoot\src\WindowEnumerationAPI.cs"
$mouseControlAPISourcecodePath = "$PSScriptRoot\src\MouseControlAPI.cs"
$screenCaptureApiPath = "$PSScriptRoot\src\ScreenCaptureAPI.cs"
$consoleAppBridgePath = "$PSScriptRoot\src\ConsoleAppBridge.cs"

$spectreConsolePath        = "$PSScriptRoot\lib\Spectre.Console.dll"
$spectreTestingConsolePath = "$PSScriptRoot\lib\test\Spectre.Console.Testing.dll"

$script:ModuleRootPath = $PSScriptRoot

$privateScriptRoot = Join-Path $PSScriptRoot 'Private'
$publicScriptRoot = Join-Path $PSScriptRoot 'Public'

# Check for fatal logging initialization flag
if ($global:LastWarAutoScreenshot_LoggingInitFailed) {
    return
}

# Dependency checks before loading C# types
# Check .NET 9 runtime using environment/version info (avoids type loading issues)
$dotNetOk = $false
$currentRuntime = "Unknown"

try {
    # Try to detect .NET 9 from $PSHOME path or PSVersionTable
    if ($PSHOME -like "*9*" -or $PSVersionTable.PSVersion.Major -ge 7) {
        # For PS 7.4+, check if we can access System.Runtime
        $dotNetOk = $true
        try {
            # Load System.Runtime to get accurate version info
            Add-Type -AssemblyName 'System.Runtime'
            $runtimeInfo = [System.Runtime.RuntimeInformation]::FrameworkDescription
            $currentRuntime = $runtimeInfo
            $dotNetOk = $runtimeInfo -like "*.NET 9*"
        } catch {
            # If we can't load the type, assume we're on a compatible runtime
            $currentRuntime = "PowerShell $($PSVersionTable.PSVersion)"
            $dotNetOk = $true
        }
    }
} catch {
    $dotNetOk = $false
    $currentRuntime = "Unable to determine runtime"
}

if (-not $dotNetOk) {
    $errorMsg = @"
Missing dependency: .NET 9 or Spectre.Console.dll
Run Install-LastWarAutoScreenshot to fix.
Current runtime: $currentRuntime
"@
    Write-Error $errorMsg.Trim()
    $global:LastWarAutoScreenshot_LoggingInitFailed = $true
    return
}

# Check Spectre.Console.dll exists
if (-not (Test-Path $spectreConsolePath)) {
    Write-Error "Missing dependency: .NET 9 or Spectre.Console.dll. Run Install-LastWarAutoScreenshot to fix."
    $global:LastWarAutoScreenshot_LoggingInitFailed = $true
    return
}

# Check Spectre.Console.Testing.dll exists (required by the test suite only)
if (-not (Test-Path $spectreTestingConsolePath)) {
    Write-Warning "Spectre.Console.Testing.dll not found. Tests will not run. Run Install-LastWarAutoScreenshot to install it."
}

# 1. Check all files exist
$missingFiles = @()
foreach ($f in @($logBackendSourcecodePath, $fileLogBackendSourcecodePath, $windowEnumerationAPISourcecodePath, $mouseControlAPISourcecodePath, $screenCaptureApiPath, $consoleAppBridgePath, $spectreConsolePath)) {
    if (-not (Test-Path $f)) { $missingFiles += $f }
}
if ($missingFiles.Count -gt 0) {
    Write-Error "[FATAL] Missing required C# source files: $($missingFiles -join ', ')"
    return
}

# 2. Check if any types are already loaded
$typeNames = @(
    'LastWarAutoScreenshot.LogBackend',
    'LastWarAutoScreenshot.FileLogBackend',
    'LastWarAutoScreenshot.WindowEnumerationAPI',
    'LastWarAutoScreenshot.EnumWindowsProc',
    'LastWarAutoScreenshot.MouseControlAPI',
    'LastWarAutoScreenshot.ScreenCaptureAPI',
    'LastWarAutoScreenshot.ConsoleAppBridge'
)
$alreadyLoaded = $typeNames | Where-Object { ($_ -as [type]) -ne $null }
if ($alreadyLoaded.Count -gt 0) {
    Write-Verbose ("C# types already loaded in this session: " + ($alreadyLoaded -join ', ') + ". Skipping Add-Type and reloading functions.")
} else {
    # 3. Load Spectre.Console DLL first (must precede any compilation that references it)
    Add-Type -Path $spectreConsolePath

    # 4. Compile all C# source files in one pass so ScreenCaptureAPI.cs can reference
    #    MouseControlAPI.RECT and MouseControlAPI.GetWindowRect directly.
    #    ScreenCaptureAPI.cs contains only the PrintWindow P/Invoke — bitmap creation,
    #    cropping, and PNG saving are done in PowerShell using System.Drawing at runtime
    #    to avoid compiling against System.Drawing.Common here (System.Private.CoreLib
    #    and System.Private.Windows.Core have empty or runtime-only locations in .NET 9
    #    and cannot be reliably resolved via -ReferencedAssemblies).
    #    ConsoleAppBridge references Spectre.Console and is compiled separately below.
    Add-Type -Path $logBackendSourcecodePath, $fileLogBackendSourcecodePath, $windowEnumerationAPISourcecodePath, $mouseControlAPISourcecodePath, $screenCaptureApiPath
    Add-Type -Path $consoleAppBridgePath -ReferencedAssemblies $spectreConsolePath
}

# Load System.Drawing.Common so the screenshot PowerShell wrapper functions can use
# System.Drawing.Bitmap, Graphics, ImageFormat, etc. at runtime without a C# compile step.
# This is idempotent — safe to call even if the assembly is already loaded.
Add-Type -AssemblyName 'System.Drawing.Common'

# Dot-source all public and private functions, handling missing folders gracefully

if (Test-Path $publicScriptRoot) {
    Write-Verbose "Dot-sourcing public functions"
    foreach ($sourceFile in Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1) {
        try {
            . $sourceFile
            if ($global:LastWarAutoScreenshot_LoggingInitFailed) { return }
        } catch {
            # Fallback log to local file if possible
            try {
                $logFilePath = Join-Path $script:ModuleRootPath 'LastWarAutoScreenshot.log'
                $msg = "[IMPORT ERROR] Failed to dot-source $($sourceFile.FullName): $_"
                Add-Content -Path $logFilePath -Value $msg
            } catch {}
            throw
        }
    }
}
if (Test-Path "$privateScriptRoot") {
    Write-Verbose "Dot-sourcing private functions"
    # Dot-source helpers first so all scripts can use them
    if (Test-Path "$privateScriptRoot\LastWarAutoScreenshotHelpers.ps1") {
        . "$privateScriptRoot\LastWarAutoScreenshotHelpers.ps1"
    }

    foreach ($sourceFile in Get-ChildItem -Path "$privateScriptRoot" -Filter *.ps1) {
        try {
            . $sourceFile
            if ($global:LastWarAutoScreenshot_LoggingInitFailed) { return }
        } catch {
            # Fallback log to local file if possible
            try {
                $logFilePath = Join-Path $PSScriptRoot 'LastWarAutoScreenshot.log'
                $msg = "[IMPORT ERROR] Failed to dot-source $($sourceFile.FullName): $_"
                Add-Content -Path $logFilePath -Value $msg
            } catch {}
            throw
        }
    }

    # Dot-source ConsoleApp subfolder after other private functions to ensure dependencies are loaded
    $consoleAppScriptRoot = Join-Path $privateScriptRoot 'ConsoleApp'
    if (Test-Path $consoleAppScriptRoot) {
        Write-Verbose "Dot-sourcing ConsoleApp private functions"
        foreach ($sourceFile in Get-ChildItem -Path $consoleAppScriptRoot -Filter *.ps1) {
            try {
                . $sourceFile
                if ($global:LastWarAutoScreenshot_LoggingInitFailed) { return }
            } catch {
                try {
                    $logFilePath = Join-Path $PSScriptRoot 'LastWarAutoScreenshot.log'
                    $msg = "[IMPORT ERROR] Failed to dot-source $($sourceFile.FullName): $_"
                    Add-Content -Path $logFilePath -Value $msg
                } catch {}
                throw
            }
        }
    }
}

# ── Test console dimensions ────────────────────────────────────────────────────
# Width and height for the Spectre.Console TestConsole injected by Pester tests.
# Wide dimensions prevent table cell wrapping, eliminating regex test flakiness.
# Change these values here to affect all test files simultaneously.
$script:TestConsoleWidth  = 2560
$script:TestConsoleHeight = 1440

# Explicitly export Get-MonitorProcess first for testability
Export-ModuleMember -Function Get-MonitorProcess
# Explicitly export main entry point (Phase 3)
Export-ModuleMember -Function Start-LastWarAutoScreenshot
# Export all other public functions except those already exported above
Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 | ForEach-Object {
    if ($_.BaseName -notin @('Get-MonitorProcess', 'Start-LastWarAutoScreenshot')) {
        Export-ModuleMember -Function $_.BaseName
    }
}
