# Robust C# type loader: check file existence, abort if missing, check for loaded types, abort if loaded, else Add-Type

$logBackendSourcecodePath = "$PSScriptRoot\src\LogBackend.cs"
$fileLogBackendSourcecodePath = "$PSScriptRoot\src\FileLogBackend.cs"
$windowEnumerationAPISourcecodePath = "$PSScriptRoot\src\WindowEnumerationAPI.cs"
$mouseControlAPISourcecodePath = "$PSScriptRoot\src\MouseControlAPI.cs"
$consoleAppBridgePath = "$PSScriptRoot\src\ConsoleAppBridge.cs"

$spectreConsolePath = "$PSScriptRoot\lib\Spectre.Console.dll"

$script:ModuleRootPath = $PSScriptRoot

$privateScriptRoot = Join-Path $PSScriptRoot 'Private'
$publicScriptRoot = Join-Path $PSScriptRoot 'Public'

# Check for fatal logging initialization flag
if ($global:LastWarAutoScreenshot_LoggingInitFailed) {
    return
}

# 1. Check all files exist
$missingFiles = @()
foreach ($f in @($logBackendSourcecodePath, $fileLogBackendSourcecodePath, $windowEnumerationAPISourcecodePath, $mouseControlAPISourcecodePath, $consoleAppBridgePath, $spectreConsolePath)) {
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
    'LastWarAutoScreenshot.ConsoleAppBridge'
)
$alreadyLoaded = $typeNames | Where-Object { ($_ -as [type]) -ne $null }
if ($alreadyLoaded.Count -gt 0) {
    Write-Verbose ("C# types already loaded in this session: " + ($alreadyLoaded -join ', ') + ". Skipping Add-Type and reloading functions.")
} else {
    # 3. Load Spectre.Console DLL first (must precede any compilation that references it)
    Add-Type -Path $spectreConsolePath

    # 4. Compile all C# source files; ConsoleAppBridge references Spectre.Console
    Add-Type -Path $logBackendSourcecodePath, $fileLogBackendSourcecodePath, $windowEnumerationAPISourcecodePath, $mouseControlAPISourcecodePath
    Add-Type -Path $consoleAppBridgePath -ReferencedAssemblies $spectreConsolePath
}

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
