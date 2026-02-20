# Robust C# type loader: check file existence, abort if missing, check for loaded types, abort if loaded, else Add-Type

$logBackendSourcecodePath = "$PSScriptRoot\src\LogBackend.cs"
$fileLogBackendSourcecodePath = "$PSScriptRoot\src\FileLogBackend.cs"
$windowEnumerationAPISourcecodePath = "$PSScriptRoot\src\WindowEnumerationAPI.cs"
$mouseControlAPISourcecodePath = "$PSScriptRoot\src\MouseControlAPI.cs"

$script:ModuleRootPath = $PSScriptRoot

$privateScriptRoot = Join-Path $PSScriptRoot 'Private'
$publicScriptRoot = Join-Path $PSScriptRoot 'Public'

# Check for fatal logging initialization flag
if ($global:LastWarAutoScreenshot_LoggingInitFailed) {
    return
}

# 1. Check all files exist
$missingFiles = @()
foreach ($f in @($logBackendSourcecodePath, $fileLogBackendSourcecodePath, $windowEnumerationAPISourcecodePath, $mouseControlAPISourcecodePath)) {
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
    'LastWarAutoScreenshot.MouseControlAPI'
)
$alreadyLoaded = $typeNames | Where-Object { ($_ -as [type]) -ne $null }
if ($alreadyLoaded.Count -gt 0) {
    Write-Verbose ("C# types already loaded in this session: " + ($alreadyLoaded -join ', ') + ". Skipping Add-Type and reloading functions.")
} else {
    # 3. Add all types at once
    Add-Type -Path $logBackendSourcecodePath, $fileLogBackendSourcecodePath, $windowEnumerationAPISourcecodePath, $mouseControlAPISourcecodePath
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
}

# Explicitly export Get-MonitorProcess first for testability
Export-ModuleMember -Function Get-MonitorProcess
# Export all other public functions except duplicates
Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 | ForEach-Object {
    if ($_.BaseName -ne 'Get-MonitorProcess') { Export-ModuleMember -Function $_.BaseName }
}
