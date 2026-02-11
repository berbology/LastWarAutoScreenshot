# Quick script to check Get-EnumeratedWindows returns real data
# Run this in a PowerShell 7+ session with the module loaded and required type definitions sourced

# Dot-source the type definitions and function if not already loaded
. "$PSScriptRoot/WindowEnumeration_TypeDefinition.ps1"
. "$PSScriptRoot/Get-EnumeratedWindows.ps1"

# Call the function and output results
$windows = Get-EnumeratedWindows -Verbose

# Display a summary table
$windows | Select-Object ProcessName, WindowTitle, WindowHandleString, ProcessID, WindowState | Format-Table -AutoSize

# Show count
"Total windows found: $($windows.Count)"
