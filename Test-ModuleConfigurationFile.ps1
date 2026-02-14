# Test script for Project Plan Task 1.4: Select-TargetWindowFromMenu
# This script dot-sources the relevant function and runs it as a user would


$privatePath = "src/LastWarAutoClickScreenshot/private"

# Dot-source required type definitions first
. "$privatePath/WindowEnumeration_TypeDefinition.ps1"


# Dot-source the function scripts
. "$privatePath/Get-EnumeratedWindows.ps1"
. "$privatePath/Select-TargetWindowFromMenu.ps1"
. "$privatePath/Save-ModuleConfiguration.ps1"
. "$privatePath/Get-ModuleConfiguration.ps1"


Write-Host "Enumerating windows..."
$windows = Get-EnumeratedWindows

if (-not $windows) {
    Write-Host "No windows found. Exiting."
    exit 1
}

Write-Host "Invoking Select-TargetWindowFromMenu..."
$selected = $windows | Select-TargetWindowFromMenu

Write-Host "Selected window:"
$selected | Format-List

# Test saving configuration to default location
Write-Host "Saving selected window configuration to default location..."
$saveResult = Save-ModuleConfiguration -WindowObject $selected -Force
if ($saveResult) {
    Write-Host "Configuration saved: $($saveResult.FullName)"
} else {
    Write-Host "Failed to save configuration. Exiting."
    exit 2
}

# Test retrieving configuration from default location
Write-Host "Retrieving configuration from default location..."
$retrievedConfig = Get-ModuleConfiguration
if ($retrievedConfig) {
    Write-Host "Configuration retrieved from file:"
    $retrievedConfig | Format-List
} else {
    Write-Host "Failed to retrieve configuration. Exiting."
    exit 3
}

# Compare selected and retrieved config (basic check)
Write-Host "Verifying round-trip integrity..."
$propsToCheck = @('ProcessName','WindowTitle','WindowHandleString','WindowHandleInt64','ProcessID','WindowState')
$selectedForCompare = [PSCustomObject]@{
    ProcessName = $selected.ProcessName
    WindowTitle = $selected.WindowTitle
    WindowHandleString = $selected.WindowHandle.ToString()
    WindowHandleInt64 = [int64]$selected.WindowHandle
    ProcessID = $selected.ProcessID
    WindowState = $selected.WindowState
}
$retrievedForCompare = [PSCustomObject]@{
    ProcessName = $retrievedConfig.ProcessName
    WindowTitle = $retrievedConfig.WindowTitle
    WindowHandleString = $retrievedConfig.WindowHandleString
    WindowHandleInt64 = $retrievedConfig.WindowHandleInt64
    ProcessID = $retrievedConfig.ProcessID
    WindowState = $retrievedConfig.WindowState
}

$diff = Compare-Object -ReferenceObject $selectedForCompare -DifferenceObject $retrievedForCompare -Property $propsToCheck
if ($diff) {
    Write-Host "Round-trip test FAILED. Differences detected:" -ForegroundColor Red
    $diff | Format-Table
    exit 4
} else {
    Write-Host "Round-trip test PASSED. Saved and loaded configuration match." -ForegroundColor Green
}
