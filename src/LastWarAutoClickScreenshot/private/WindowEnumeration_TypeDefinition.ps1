<#
.SYNOPSIS
    Defines P/Invoke signatures for Win32 API window enumeration functions.

.DESCRIPTION
    This script defines the necessary Win32 API functions and delegates for enumerating
    windows, retrieving window information, and checking window states. All functions
    are defined in the User32.dll library.

.NOTES
    Memory Management:
    - Window handles (HWND) are managed by Windows and do not require cleanup
    - The EnumWindowsProc delegate must remain in scope during enumeration to prevent
      premature garbage collection by the CLR
    - StringBuilder objects for GetWindowText are automatically managed by .NET

    Error Handling:
    - All functions return error codes or boolean values that should be checked
    - Use try-catch blocks when calling these functions from PowerShell
    - GetLastError() can be called via [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()

.EXAMPLE
    # This file is dot-sourced by the module and should not be called directly
    # See Get-EnumeratedWindows for usage examples

    # Example: Find and print details for a window by process ID (interactive use)
    # Usage: Set $targetPid to the PID of the process you want to find (e.g., LastWar.exe)
    #
    # . 'c:\git\LastWarAutoScreenshot\src\LastWarAutoClickScreenshot\private\WindowEnumeration_TypeDefinition.ps1'
    # $targetPid = 12345
    # $global:found = $false
    # $callback = [EnumWindowsProc] {
    #     param($hwnd, $lParam)
    #     $procId = 0
    #     [WindowEnumerationAPI]::GetWindowThreadProcessId($hwnd, [ref]$procId) | Out-Null
    #     if ($procId -eq $targetPid -and [WindowEnumerationAPI]::IsWindowVisible($hwnd)) {
    #         $titleLen = [WindowEnumerationAPI]::GetWindowTextLength($hwnd)
    #         $title = ''
    #         if ($titleLen -gt 0) {
    #             $sb = [System.Text.StringBuilder]::new($titleLen + 1)
    #             [WindowEnumerationAPI]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
    #             $title = $sb.ToString()
    #         }
    #         Write-Host ('Found HWND: {0} | Title: {1}' -f $hwnd, $title)
    #         $global:found = $true
    #         return $false
    #     }
    #     return $true
    # }.GetNewClosure()
    # [WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
    # if (-not $global:found) { Write-Host 'No visible window found for process' }
#>

# Only define types if they don't already exist (prevents errors on re-import)
if (-not ([System.Management.Automation.PSTypeName]'WindowEnumerationAPI').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

/// <summary>
/// Delegate for EnumWindows callback function
/// </summary>
/// <param name="hWnd">Handle to the window</param>
/// <param name="lParam">Application-defined value</param>
/// <returns>True to continue enumeration, false to stop</returns>
public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

/// <summary>
/// Provides P/Invoke signatures for Win32 window enumeration and information APIs
/// </summary>
public class WindowEnumerationAPI {
    
    /// <summary>
    /// Enumerates all top-level windows by passing handle to each window to callback function
    /// </summary>
    /// <param name="lpEnumFunc">Pointer to application-defined callback function</param>
    /// <param name="lParam">Application-defined value passed to callback</param>
    /// <returns>True if successful, false otherwise</returns>
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    
    /// <summary>
    /// Retrieves the text of the specified window's title bar
    /// </summary>
    /// <param name="hWnd">Handle to the window</param>
    /// <param name="lpString">Buffer to receive the text</param>
    /// <param name="nMaxCount">Maximum number of characters to copy</param>
    /// <returns>Length of copied string, or 0 on failure</returns>
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    
    /// <summary>
    /// Retrieves the length of the specified window's title bar text
    /// </summary>
    /// <param name="hWnd">Handle to the window</param>
    /// <returns>Length of text in characters, or 0 if no title</returns>
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    
    /// <summary>
    /// Determines visibility state of the specified window
    /// </summary>
    /// <param name="hWnd">Handle to the window</param>
    /// <returns>True if window is visible, false otherwise</returns>
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    /// <summary>
    /// Retrieves the identifier of the thread and process that created the window
    /// </summary>
    /// <param name="hWnd">Handle to the window</param>
    /// <param name="lpdwProcessId">Pointer to variable that receives process identifier</param>
    /// <returns>Identifier of the thread that created the window</returns>
    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    
    /// <summary>
    /// Determines whether the specified window is minimized (iconic)
    /// </summary>
    /// <param name="hWnd">Handle to the window</param>
    /// <returns>True if window is minimized, false otherwise</returns>
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsIconic(IntPtr hWnd);
    
    /// <summary>
    /// Retrieves a handle to the foreground window (the window with which the user is currently working)
    /// </summary>
    /// <returns>Handle to the foreground window, or IntPtr.Zero if no foreground window exists</returns>
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetForegroundWindow();
}
'@ -ErrorAction Stop
}

<#
.NOTES
    Usage Example - Delegate Lifetime Management:
    
    # CORRECT - Delegate stored in variable to prevent garbage collection
    $callback = [EnumWindowsProc] {
        param($hwnd, $lParam)
        # Process window...
        return $true  # Continue enumeration
    }
    [WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero)
    
    # INCORRECT - Inline delegate may be collected by GC during enumeration
    [WindowEnumerationAPI]::EnumWindows(
        [EnumWindowsProc] { param($hwnd, $lParam); return $true },
        [IntPtr]::Zero
    )
    
    Error Handling Example:
    
    try {
        $result = [WindowEnumerationAPI]::EnumWindows($callback, [IntPtr]::Zero)
        if (-not $result) {
            $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $msg = "EnumWindows failed with error code: $errorCode"
            Write-Error "Error: $msg"
            Write-LastWarLog -Message $msg -Level Error -FunctionName 'WindowEnumeration_TypeDefinition' -Context 'EnumWindows'
            throw $msg
        }
    }
    catch {
        Write-Error "Error: Failed to enumerate windows: $_"
        Write-LastWarLog -Message "Failed to enumerate windows: $_" -Level Error -FunctionName 'WindowEnumeration_TypeDefinition' -Context 'EnumWindows' -StackTrace $_
    }
#>
