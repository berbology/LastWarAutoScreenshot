# Wrapper for GetWindowThreadProcessId
function Invoke-GetWindowThreadProcessId {
    param([IntPtr]$WindowHandle, [ref]$ProcessId)
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowThreadProcessId($WindowHandle, [ref]$ProcessId)
}

# Wrapper for GetWindowTextLength
function Invoke-GetWindowTextLength {
    param([IntPtr]$WindowHandle)
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowTextLength($WindowHandle)
}

# Wrapper for GetWindowText
function Invoke-GetWindowText {
    param([IntPtr]$WindowHandle, [System.Text.StringBuilder]$StringBuilder, [int]$Capacity)
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::GetWindowText($WindowHandle, $StringBuilder, $Capacity)
}
#
# Set-WindowActive.ps1
# Brings a window to the foreground (activates it) by handle, name, or process ID.
#
<#
.SYNOPSIS
    Brings a window to the foreground (activates it) by handle, window name, or process ID.

.DESCRIPTION
    Calls SetForegroundWindow Win32 API via WindowEnumerationAPI type definition.
    Supports lookup by WindowHandle, WindowName, or ProcessID.
    Handles errors and logs using the standard backend.

.PARAMETER WindowHandle
    The handle (IntPtr or int64) of the window to activate.

.PARAMETER WindowName
    (Optional) The window title to activate.

.PARAMETER ProcessID
    (Optional) The process ID of the window to activate.

.EXAMPLE
    Set-WindowActive -WindowHandle 123456

.EXAMPLE
    Set-WindowActive -WindowName 'Last War: Survival'

.EXAMPLE
    Set-WindowActive -ProcessID 12345
#>


function Invoke-SetForegroundWindow {
    param([IntPtr]$WindowHandle)
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::SetForegroundWindow($WindowHandle)
}

function Invoke-EnumWindows {
    param([LastWarAutoScreenshot.EnumWindowsProc]$Callback, [IntPtr]$lParam)
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::EnumWindows($Callback, $lParam)
}

function Set-WindowActive {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [Alias('hWnd')]
        [object]$WindowHandle,

        [Parameter(Position=1, Mandatory=$false)]
        [string]$WindowName,

        [Parameter(Position=2, Mandatory=$false)]
        [int]$ProcessID
    )
    # Removed dot-sourcing of missing WindowEnumeration_TypeDefinition.ps1; types are loaded by module import

    function Resolve-WindowHandle {
        param(
            [string]$WindowName,
            [int]$ProcessID
        )
        $foundHandle = $null
        $callback = [LastWarAutoScreenshot.EnumWindowsProc] {
            param($hwnd, $lParam)
            $procId = 0
            Invoke-GetWindowThreadProcessId -WindowHandle $hwnd -ProcessId ([ref]$procId) | Out-Null
            $titleLen = Invoke-GetWindowTextLength -WindowHandle $hwnd
            $title = ''
            if ($titleLen -gt 0) {
                $sb = [System.Text.StringBuilder]::new($titleLen + 1)
                Invoke-GetWindowText -WindowHandle $hwnd -StringBuilder $sb -Capacity $sb.Capacity | Out-Null
                $title = $sb.ToString()
            }
            if (($WindowName -and $title -eq $WindowName) -or ($ProcessID -and $procId -eq $ProcessID)) {
                $foundHandle = $hwnd
                return $foundHandle
            }
            return $true
        }.GetNewClosure()
        $result = Invoke-EnumWindows -Callback $callback -lParam ([IntPtr]::Zero)
        if ($result -is [IntPtr] -and $result -ne [IntPtr]::Zero) {
            return $result
        }
        return $foundHandle
    }

    try {
        $hWnd = $null
        if ($WindowHandle) {
            if ($WindowHandle -is [array]) {
                Write-LastWarLog -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)" -Level Error -FunctionName 'Set-WindowActive' -Context "ParameterValidation"
                Write-Host "`e[31mERROR: Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)`e[0m"
                return $false
            } elseif ($WindowHandle -is [IntPtr]) {
                $hWnd = $WindowHandle
            } elseif ($WindowHandle -is [string] -or $WindowHandle -is [int64] -or $WindowHandle -is [int]) {
                $hWnd = [IntPtr]::new([int64]$WindowHandle)
            } else {
                Write-LastWarLog -Message "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)" -Level Error -FunctionName 'Set-WindowActive' -Context "ParameterValidation"
                Write-Host "`e[31mERROR: Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)`e[0m"
                return $false
            }
        } elseif ($WindowName -or $ProcessID) {
            $hWnd = Resolve-WindowHandle -WindowName $WindowName -ProcessID $ProcessID
            if (-not $hWnd) {
                $msg = "No window found matching criteria."
                Write-LastWarLog -Message $msg -Level Error -FunctionName 'Set-WindowActive' -Context "WindowLookup"
                Write-Host "`e[31mERROR: $msg`e[0m"
                return $false
            }
        } else {
            Write-LastWarLog -Message "No valid window criteria provided." -Level Error -FunctionName 'Set-WindowActive' -Context "ParameterValidation"
            Write-Host "`e[31mERROR: No valid window criteria provided.`e[0m"
            return $false
        }
        $result = Invoke-SetForegroundWindow -WindowHandle $hWnd
        if (-not $result) {
            $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $msg = "SetForegroundWindow failed for handle $hWnd with error code $err."
            Write-LastWarLog -Message $msg -Level Error -FunctionName 'Set-WindowActive' -Context "SetForegroundWindow"
            Write-Host "`e[31mERROR: $msg`e[0m"
            return $false
        }
        Write-LastWarLog -Message "Set-WindowActive succeeded for handle $hWnd" -Level Info -FunctionName 'Set-WindowActive' -Context "SetForegroundWindow"
        return $true
    } catch {
        $msg = "Exception in Set-WindowActive: $_"
        Write-LastWarLog -Message $msg -Level Error -FunctionName 'Set-WindowActive' -Context "SetForegroundWindow" -LogStackTrace $_
        Write-Host "`e[31mERROR: $msg`e[0m"
        return $false
    }
}
