# Mouse Control Helpers
# Implements wrappers for MouseControlAPI.cs methods

function Invoke-SendMouseInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$DeltaX,
        [Parameter(Mandatory)]
        [int]$DeltaY,
        [uint32]$ButtonFlags = 0
    )
    try {
        $result = [LastWarAutoScreenshot.MouseControlAPI]::SendInput($DeltaX, $DeltaY, $ButtonFlags)
        if ($result -eq 0) {
            Write-LastWarLog -Level 'Error' -Message "SendInput failed (Win32 error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))" -FunctionName 'Invoke-SendMouseInput'
            return $false
        }
        return $true
    } catch {
        Write-LastWarLog -Level 'Error' -Message $_.Exception.Message -FunctionName 'Invoke-SendMouseInput'
        return $false
    }
}

function Invoke-GetCursorPosition {
    [CmdletBinding()]
    param()
    try {
        $point = New-Object 'LastWarAutoScreenshot.MouseControlAPI+POINT'
        $success = [LastWarAutoScreenshot.MouseControlAPI]::GetCursorPos([ref]$point)
        if (-not $success) {
            Write-LastWarLog -Level 'Error' -Message "GetCursorPos failed (Win32 error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))" -FunctionName 'Invoke-GetCursorPosition'
            return $null
        }
        [PSCustomObject]@{ X = [int]$point.X; Y = [int]$point.Y }
    } catch {
        Write-LastWarLog -Level 'Error' -Message $_.Exception.Message -FunctionName 'Invoke-GetCursorPosition'
        return $null
    }
}
