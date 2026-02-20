# Define classes to control mouse cursor using Windows API functions

# SetCursorPos function to move the cursor to a specific position
 . "$PSScriptRoot/Write-LastWarLog.ps1"

# Add-Type for MouseControl (SetCursorPos and mouse_event) with try-catch wrapper function
try {
    # Only add the MouseControl type if it does not already exist
    if (-not ([System.Management.Automation.PSTypeName]'Win32.MouseControl').Type) {
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class MouseControl {
            [DllImport("user32.dll")]
            public static extern bool SetCursorPos(int X, int Y);
            [DllImport("user32.dll")]
            public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);
        }
"@ -ErrorAction Stop
    }
}
catch {
    Write-LastWarLog -Message "Failed to define MouseControl: $_" -Level Warning -FunctionName 'CursorControl_TypeDefinitions' -Context 'Add-Type' -LogStackTrace $_
    Write-Warning "Failed to define MouseControl: $_"
}

<#
Example usage:
Move cursor to position (100, 100)
[MouseControl]::SetCursorPos(100, 100)

Left mouse click: down (0x0002) then up (0x0004)
[MouseControl]::mouse_event(0x0002, 0, 0, 0, 0)  # Down
[MouseControl]::mouse_event(0x0004, 0, 0, 0, 0)  # Up
#>
