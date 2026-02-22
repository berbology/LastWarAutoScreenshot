# Get-WindowBounds.ps1

<#+
.SYNOPSIS
    Retrieves the bounds of a window given its handle.
.DESCRIPTION
    Provides two functions:
    - Invoke-GetWindowRect: Thin wrapper for [LastWarAutoScreenshot.MouseControlAPI]::GetWindowRect
    - Get-WindowBounds: Accepts various handle types, returns window bounds as PSCustomObject
.NOTES
    Part of Phase 2, Task 1.4 (Mouse Control)
    Error handling and logging via Write-LastWarLog
#>

function Invoke-GetWindowRect {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle
    )
    $rect = New-Object 'LastWarAutoScreenshot.MouseControlAPI+RECT'
    $result = [LastWarAutoScreenshot.MouseControlAPI]::GetWindowRect($WindowHandle, [ref]$rect)
    if (-not $result) {
        Write-LastWarLog -Level 'Error' -Message "GetWindowRect failed for handle $WindowHandle. Win32 error: $([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)" -Function 'Invoke-GetWindowRect'
        return $null
    }
    return $rect
}

function Get-WindowBounds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $WindowHandle
    )
    # Accept IntPtr, int64, int, string (hex or decimal)
    try {
        if ($WindowHandle -is [IntPtr]) {
            $handle = $WindowHandle
        } elseif ($WindowHandle -is [long] -or $WindowHandle -is [int]) {
            $handle = [IntPtr]::new([long]$WindowHandle)
        } elseif ($WindowHandle -is [string]) {
            if ($WindowHandle -match '^0x[0-9a-fA-F]+$') {
                $handle = [IntPtr]::new([Convert]::ToInt64($WindowHandle, 16))
            } elseif ($WindowHandle -match '^[0-9]+$') {
                $handle = [IntPtr]::new([long]$WindowHandle)
            } else {
                throw "String WindowHandle must be hex (0x...) or decimal digits."
            }
        } else {
            throw "Unsupported WindowHandle type: $($WindowHandle.GetType().FullName)"
        }
    } catch {
        Write-LastWarLog -Level 'Error' -Message "Failed to convert WindowHandle: $_" -Function 'Get-WindowBounds'
        return $null
    }
    $rect = Invoke-GetWindowRect -WindowHandle $handle
    if (-not $rect) {
        # Error already logged in Invoke-GetWindowRect
        return $null
    }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    return [PSCustomObject]@{
        Left   = $rect.Left
        Top    = $rect.Top
        Right  = $rect.Right
        Bottom = $rect.Bottom
        Width  = $width
        Height = $height
    }
}

