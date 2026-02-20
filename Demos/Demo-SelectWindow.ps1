# Demo: Run the interactive window selection menu for Last War Auto Screenshot
# This script uses Import-Module and public module functions only

$moduleManifest = Join-Path $PSScriptRoot '../LastWarAutoScreenshot.psd1'
Import-Module $moduleManifest -Force

# Enumerate all windows and launch the menu
$InformationPreference = 'Continue'
$selected = Get-EnumeratedWindows | Select-TargetWindowFromMenu

if ($selected) {
    Write-Information "Info: You selected: $($selected.ProcessName) - $($selected.WindowTitle) (Handle: $($selected.WindowHandleInt64))"
} else {
    Write-Warning "Warning: No window selected or operation cancelled."
}
