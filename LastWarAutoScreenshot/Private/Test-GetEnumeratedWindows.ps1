# Quick script to check Get-EnumeratedWindows returns real data
# Run this in a PowerShell 7+ session with the module loaded and required type definitions sourced

# Removed dot-sourcing of missing WindowEnumeration_TypeDefinition.ps1; types are loaded by module import
. "$PSScriptRoot/Get-EnumeratedWindows.ps1"

# Call the function and output results
$windows = Get-EnumeratedWindows -Verbose

# Display a summary table
$windows | Select-Object ProcessName, WindowTitle, WindowHandleString, ProcessID, WindowState | Format-Table -AutoSize

# Show count
"Total windows found: $($windows.Count)"
