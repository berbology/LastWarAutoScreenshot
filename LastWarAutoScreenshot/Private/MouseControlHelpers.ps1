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
        # Create MOUSEINPUT structure
        $mouseInput = New-Object 'LastWarAutoScreenshot.MouseControlAPI+MOUSEINPUT'
        $mouseInput.dx = $DeltaX
        $mouseInput.dy = $DeltaY
        $mouseInput.mouseData = 0
        $mouseInput.dwFlags = $ButtonFlags
        $mouseInput.time = 0
        $mouseInput.dwExtraInfo = [System.IntPtr]::Zero

        # Create INPUT structure (wrapper for MOUSEINPUT)
        $inputStruct = New-Object 'LastWarAutoScreenshot.MouseControlAPI+INPUT'
        $inputStruct.type = [LastWarAutoScreenshot.MouseControlAPI]::INPUT_MOUSE
        $inputStruct.mi = $mouseInput

        # Create INPUT array with 1 element
        $inputArray = @($inputStruct)

        # Call SendInput with proper parameters: count, array, struct size
        # IMPORTANT: Pass instance to SizeOf, not the type, to avoid marshalling errors
        $inputSize = [System.Runtime.InteropServices.Marshal]::SizeOf($inputStruct)
        $result = [LastWarAutoScreenshot.MouseControlAPI]::SendInput(1, $inputArray, $inputSize)
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

function Invoke-SetCursorPos {
    <#
    .SYNOPSIS
        Sets the mouse cursor to an absolute screen position.

    .DESCRIPTION
        Calls the Win32 SetCursorPos API to move the cursor to the specified absolute
        pixel coordinates. Unlike SendInput with MOUSEEVENTF_MOVE, this bypasses pointer
        acceleration and sets the position precisely regardless of DPI or speed settings.

    .PARAMETER X
        Absolute X coordinate in pixels.

    .PARAMETER Y
        Absolute Y coordinate in pixels.

    .OUTPUTS
        [bool] $true on success, $false on failure.

    .EXAMPLE
        Invoke-SetCursorPos -X 500 -Y 300
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$X,
        [Parameter(Mandatory)]
        [int]$Y
    )
    try {
        $result = [LastWarAutoScreenshot.MouseControlAPI]::SetCursorPos($X, $Y)
        if (-not $result) {
            Write-LastWarLog -Level 'Error' -Message "SetCursorPos failed (Win32 error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))" -FunctionName 'Invoke-SetCursorPos'
            return $false
        }
        return $true
    } catch {
        Write-LastWarLog -Level 'Error' -Message $_.Exception.Message -FunctionName 'Invoke-SetCursorPos'
        return $false
    }
}

function Invoke-SendMouseMoveAbsolute {
    <#
    .SYNOPSIS
        Moves the mouse cursor via SendInput using absolute, virtual-desktop-normalised coordinates.

    .DESCRIPTION
        Sends a MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK input event via
        SendInput. Unlike SetCursorPos, this injects movement through the hardware input queue,
        ensuring the event is processed in the same sequence as any held button events. Required for
        reliable drag operations where MOUSEEVENTF_LEFTDOWN was sent via SendInput.

        Coordinates are normalised to the 0-65535 range across the full virtual desktop so the
        function works correctly on single-monitor and multi-monitor setups alike.

    .PARAMETER X
        Absolute X coordinate in virtual-desktop pixels.

    .PARAMETER Y
        Absolute Y coordinate in virtual-desktop pixels.

    .OUTPUTS
        [bool] $true on success, $false on failure.

    .EXAMPLE
        Invoke-SendMouseMoveAbsolute -X 800 -Y 600
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$X,
        [Parameter(Mandatory)]
        [int]$Y
    )
    try {
        $vdLeft   = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_XVIRTUALSCREEN)
        $vdTop    = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_YVIRTUALSCREEN)
        $vdWidth  = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CXVIRTUALSCREEN)
        $vdHeight = [LastWarAutoScreenshot.MouseControlAPI]::GetSystemMetrics([LastWarAutoScreenshot.MouseControlAPI]::SM_CYVIRTUALSCREEN)

        if ($vdWidth -le 0 -or $vdHeight -le 0) {
            Write-LastWarLog -Level 'Error' -Message "GetSystemMetrics returned invalid virtual desktop dimensions (${vdWidth}x${vdHeight})." -FunctionName 'Invoke-SendMouseMoveAbsolute'
            return $false
        }

        $normX = [int](($X - $vdLeft) * 65535 / ($vdWidth  - 1))
        $normY = [int](($Y - $vdTop)  * 65535 / ($vdHeight - 1))

        $flags = [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_MOVE `
                 -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_ABSOLUTE `
                 -bor [LastWarAutoScreenshot.MouseControlAPI]::MOUSEEVENTF_VIRTUALDESK

        return Invoke-SendMouseInput -DeltaX $normX -DeltaY $normY -ButtonFlags $flags
    } catch {
        Write-LastWarLog -Level 'Error' -Message $_.Exception.Message -FunctionName 'Invoke-SendMouseMoveAbsolute'
        return $false
    }
}

