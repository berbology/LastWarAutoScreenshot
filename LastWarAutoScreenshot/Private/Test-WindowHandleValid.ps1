<#
.SYNOPSIS
    Checks if a window handle is still valid (window is open).

.DESCRIPTION
    Uses the Win32 API to determine if the specified window handle refers to an existing window.
    Returns $true if the window exists, $false otherwise. Handles errors and logs as per project standards.

.PARAMETER WindowHandle
    The handle (IntPtr, int64, or string) of the window to check.

.EXAMPLE
    Test-WindowHandleValid -WindowHandle 123456
#>
function Invoke-IsWindow {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$hWnd
    )
    if (-not ([System.Management.Automation.PSTypeName]'Win32IsWindowAPI').Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Win32IsWindowAPI {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsWindow(IntPtr hWnd);
}
'@ -ErrorAction Stop
    }
    return [Win32IsWindowAPI]::IsWindow($hWnd)
}

function Test-WindowHandleValid {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [object]$WindowHandle,
            [Parameter()]
            [ScriptBlock]$IsWindowFn = { param($hWnd) Invoke-IsWindow -hWnd $hWnd },
            [Parameter()]
            [ScriptBlock]$IsWindowVisibleFn = { param($hWnd) [LastWarAutoScreenshot.WindowEnumerationAPI]::IsWindowVisible($hWnd) },
            [Parameter()]
            [ScriptBlock]$IsIconicFn = { param($hWnd) [LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic($hWnd) }
        )
    try {
        if ($WindowHandle -is [array]) {
            Write-LastWarLog -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)" -Level Error -FunctionName 'Test-WindowHandleValid' -Context "ParameterValidation"
            Write-Host "`e[31mERROR: Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)`e[0m"
            return $false
        }
        $hWnd = if ($WindowHandle -is [IntPtr]) {
            $WindowHandle
        } elseif ($WindowHandle -is [string] -or $WindowHandle -is [int64] -or $WindowHandle -is [int]) {
            [IntPtr]::new([int64]$WindowHandle)
        } else {
            Write-LastWarLog -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)" -Level Error -FunctionName 'Test-WindowHandleValid' -Context "ParameterValidation"
            Write-Host "`e[31mERROR: Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)`e[0m"
            return $false
        }
        $exists = & $IsWindowFn $hWnd
        if (-not $exists) {
            return $false
        }
        # Edge case: check if window is visible
        $visible = & $IsWindowVisibleFn $hWnd
        if (-not $visible) {
            Write-LastWarLog -Message "Window handle $hWnd is not visible." -Level Info -FunctionName 'Test-WindowHandleValid' -Context "VisibilityCheck"
            return $false
        }
        # Edge case: check if window is minimized (iconic)
        $minimized = & $IsIconicFn $hWnd
        if ($minimized) {
            Write-LastWarLog -Message "Window handle $hWnd is minimized (iconic)." -Level Info -FunctionName 'Test-WindowHandleValid' -Context "MinimizedCheck"
            return $false
        }
        return $true
    } catch {
        Write-LastWarLog -Message "Failed to check window handle validity: $_" -Level Error -FunctionName 'Test-WindowHandleValid' -Context "IsWindow API call" -LogStackTrace $_
        Write-Host "`e[31mERROR: Failed to check window handle validity: $_`e[0m"
        return $false
    }
}
