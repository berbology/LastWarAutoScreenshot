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


$InformationPreference = 'Continue'
Write-Information "Info: Enumerating windows..."
$windows = Get-EnumeratedWindows

if (-not $windows) {
    Write-Error "Error: No windows found. Exiting."
    exit 1
}

$InformationPreference = 'Continue'
Write-Information "Info: Invoking Select-TargetWindowFromMenu..."
$selected = $windows | Select-TargetWindowFromMenu

Write-Information "Info: Selected window:"
$selected | Format-List

# Test saving configuration to default location
$InformationPreference = 'Continue'
Write-Information "Info: Saving selected window configuration to default location..."
$saveResult = Save-ModuleConfiguration -WindowObject $selected -Force
if ($saveResult) {
    Write-Information "Info: Configuration saved: $($saveResult.FullName)"
} else {
    Write-Error "Error: Failed to save configuration. Exiting."
    exit 2
}

# Test retrieving configuration from default location
$InformationPreference = 'Continue'
Write-Information "Info: Retrieving configuration from default location..."
$retrievedConfig = Get-ModuleConfiguration
if ($retrievedConfig) {
    Write-Information "Info: Configuration retrieved from file:"
    $retrievedConfig | Format-List
} else {
    Write-Error "Error: Failed to retrieve configuration. Exiting."
    exit 3
}

# Compare selected and retrieved config (basic check)
$InformationPreference = 'Continue'
Write-Information "Info: Verifying round-trip integrity..."
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
    Write-Error "Error: Round-trip test FAILED. Differences detected:"
    $diff | Format-Table
    exit 4
} else {
    Write-Information "Info: Round-trip test PASSED. Saved and loaded configuration match."
}
