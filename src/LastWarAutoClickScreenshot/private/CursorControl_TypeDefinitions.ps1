# Define classes to control mouse cursor using Windows API functions

# SetCursorPos function to move the cursor to a specific position
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MouseControl {
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);
}
'@

<#
Example usage:
Move cursor to position (100, 100)

[MouseControl]::SetCursorPos(100, 100)
#>

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MouseControl {
    [DllImport("user32.dll")]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);
}
'@

<#
Example usage:
Left mouse click: down (0x0002) then up (0x0004)

[MouseControl]::mouse_event(0x0002, 0, 0, 0, 0)  # Down
[MouseControl]::mouse_event(0x0004, 0, 0, 0, 0)  # Up
#>
