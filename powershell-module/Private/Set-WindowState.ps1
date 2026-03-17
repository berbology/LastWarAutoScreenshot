<#
.SYNOPSIS
    Sets the window state (minimise, maximise, or restore) for a given window handle.

.DESCRIPTION
    Calls the ShowWindow Win32 API via the WindowEnumerationAPI type definition.
    Supports minimise (SW_MINIMIZE), maximise (SW_MAXIMIZE), and restore (SW_RESTORE) states.
    Handles errors and logs using the standard backend.

.PARAMETER WindowHandle
    The handle (IntPtr or int64) of the window to modify.

.PARAMETER State
    The desired state: 'Minimize', 'Maximize', or 'Restore'.

.EXAMPLE
    Set-WindowState -WindowHandle 123456 -State Minimize

.EXAMPLE
    Set-WindowState -WindowHandle 123456 -State Maximize

.EXAMPLE
    Set-WindowState -WindowHandle 123456 -State Restore
    Restores a minimised or maximised window to its original size and position.
#>

function Invoke-ShowWindow {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,
        [Parameter(Mandatory)]
        [int]$CmdShow
    )
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::ShowWindow($WindowHandle, $CmdShow)
}

function Set-WindowState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('hWnd')]
        [AllowNull()]
        [object]$WindowHandle,

        [Parameter(Mandatory)]
        [ValidateSet('Minimize','Maximize','Restore')]
        [string]$State
    )
    $SW_MINIMIZE = 2
    $SW_MAXIMIZE = 3
    $SW_RESTORE  = 9
    $cmdShow = switch ($State) {
        'Minimize' { $SW_MINIMIZE }
        'Maximize' { $SW_MAXIMIZE }
        'Restore'  { $SW_RESTORE  }
    }
    try {
        # Reject null outright
        if ($null -eq $WindowHandle) {
            Write-LastWarLog -Message "Unsupported WindowHandle type: null" -Level Error -FunctionName 'Set-WindowState' -Context "ParameterValidation"
            return $false
        }
        # Convert handle if needed
        if ($WindowHandle -is [array]) {
            Write-LastWarLog -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)" -Level Error -FunctionName 'Set-WindowState' -Context "ParameterValidation"
            return $false
        }
        $hWnd = if ($WindowHandle -is [IntPtr]) {
            $WindowHandle
        } elseif ($WindowHandle -is [string] -or $WindowHandle -is [int64] -or $WindowHandle -is [int]) {
            if ($WindowHandle -is [string] -and [string]::IsNullOrWhiteSpace($WindowHandle)) {
                Write-LastWarLog -Message "Unsupported WindowHandle type: empty string" -Level Error -FunctionName 'Set-WindowState' -Context "ParameterValidation"
                Write-Host "`e[31mERROR: Unsupported WindowHandle type: empty string`e[0m"
                return $false
            }
            [IntPtr]::new([int64]$WindowHandle)
        } else {
            Write-LastWarLog -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)" -Level Error -FunctionName 'Set-WindowState' -Context "ParameterValidation"
            Write-Host "`e[31mERROR: Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)`e[0m"
            return $false
        }
        $result = Invoke-ShowWindow -WindowHandle $hWnd -CmdShow $cmdShow
        if (-not $result) {
            $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $msg = "ShowWindow failed for handle $hWnd with error code $err."
            Write-LastWarLog -Message $msg -Level Error -FunctionName 'Set-WindowState' -Context "ShowWindow $State"
            Write-Host "`e[31mERROR: $msg`e[0m"
            return $false
        }
        Write-LastWarLog -Message "Set-WindowState succeeded for handle $hWnd ($State)" -Level Info -FunctionName 'Set-WindowState' -Context "ShowWindow $State"
        return $true
    } catch {
        $msg = "Exception in Set-WindowState: $_"
        Write-LastWarLog -Message $msg -Level Error -FunctionName 'Set-WindowState' -Context "ShowWindow $State" -LogStackTrace $_
        Write-Host "`e[31mERROR: $msg`e[0m"
        return $false
    }
}

