# Demo: Run the interactive window selection menu for Last War Auto Screenshot
# This script assumes you are running from the project root and all dependencies are present.

# Dot-source the function file directly (no module import required)
. "$PSScriptRoot\src\LastWarAutoClickScreenshot\private\Select-TargetWindowFromMenu.ps1"
. "$PSScriptRoot\src\LastWarAutoClickScreenshot\private\Get-EnumeratedWindows.ps1"
. "$PSScriptRoot\src\LastWarAutoClickScreenshot\private\WindowEnumeration_TypeDefinition.ps1"

# Enumerate all windows and launch the menu
$selected = Get-EnumeratedWindows | Select-TargetWindowFromMenu

if ($selected) {
    Write-Host "You selected: $($selected.ProcessName) - $($selected.WindowTitle) (Handle: $($selected.WindowHandleInt64))"
} else {
    Write-Host "No window selected or operation cancelled."
}
