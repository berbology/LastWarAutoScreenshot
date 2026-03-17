function Invoke-IsIconic {
    <#
    .SYNOPSIS
        Thin wrapper around the Win32 IsIconic API call, used to allow mocking in tests.
    #>
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle
    )
    return [LastWarAutoScreenshot.WindowEnumerationAPI]::IsIconic($WindowHandle)
}

function Start-LWASAutomationSequence {
    <#
    .SYNOPSIS
        Executes a named macro against one or more target windows.

    .DESCRIPTION
        Accepts window objects from Get-LWASTargetWindow via the pipeline. For each window:
          1. Validates the window handle is still live.
          2. Reads the module configuration.
          3. Restores the window if it is minimised, then waits for the configured delay.
          4. Loads the named macro via Get-LWASMacro.
          5. Executes the macro via Invoke-MacroSequence (which manages the emergency stop
             monitor lifecycle internally).
          6. Writes a result object to the pipeline.

        Non-terminating errors (Write-Error) are emitted when a window handle is invalid or
        a macro cannot be loaded; pipeline processing continues for subsequent window objects.

    .PARAMETER WindowObject
        Mandatory. A window object as returned by Get-LWASTargetWindow. Must have WindowHandle,
        ProcessName, WindowTitle, and WindowState properties.

    .PARAMETER MacroName
        Mandatory. The name of the macro to execute (matches the Name property of the macro,
        not the filename).

    .OUTPUTS
        PSCustomObject
        One result object per processed window with properties:
          Success      [bool]   — whether the macro completed without error
          MacroName    [string] — the macro name that was requested
          WindowTitle  [string] — the window title the macro ran against
          Message      [string] — success or failure detail

    .EXAMPLE
        # Scheduled-task use: find one instance of the game and run a macro
        Get-LWASTargetWindow -ProcessName 'lastwar.exe' -First |
            Start-LWASAutomationSequence -MacroName 'DailyLogin'

    .EXAMPLE
        # Multi-instance use: run the same macro against every matching window
        Get-LWASTargetWindow -ProcessName 'lastwar.exe' |
            Start-LWASAutomationSequence -MacroName 'DailyLogin'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$WindowObject,

        [Parameter(Mandatory)]
        [string]$MacroName
    )

    process {
        # 1. Validate window handle
        $isValid = Test-WindowHandleValid -WindowHandle $WindowObject.WindowHandle
        if (-not $isValid) {
            $msg = "Window '$($WindowObject.WindowTitle)' is no longer valid."
            Write-Error $msg
            Write-Output ([PSCustomObject]@{
                Success     = $false
                MacroName   = $MacroName
                WindowTitle = $WindowObject.WindowTitle
                Message     = $msg
            })
            return
        }

        # 2. Read config
        $config = Get-ModuleConfiguration

        # 3. Restore if minimised
        if (Invoke-IsIconic -WindowHandle $WindowObject.WindowHandle) {
            Set-WindowState -WindowHandle $WindowObject.WindowHandle -State 'Restore' | Out-Null
            Write-LastWarLog -Level Info `
                -Message "Restored minimised window '$($WindowObject.WindowTitle)' before macro execution." `
                -FunctionName 'Start-LWASAutomationSequence'
            Start-Sleep -Milliseconds $config.MacroExecution.WindowRestoreDelayMs
        }

        # 4. Load macro
        $macroResults = @(Get-LWASMacro -Name $MacroName -ErrorAction SilentlyContinue)
        if ($macroResults.Count -eq 0) {
            $msg = "Macro '$MacroName' could not be loaded."
            Write-Error $msg
            Write-Output ([PSCustomObject]@{
                Success     = $false
                MacroName   = $MacroName
                WindowTitle = $WindowObject.WindowTitle
                Message     = $msg
            })
            return
        }
        $macroItem = $macroResults[0]

        # Build the data object that Invoke-MacroSequence expects
        $macroData = [PSCustomObject]@{
            metadata = $macroItem.Metadata
            sequence = $macroItem.Sequence
        }

        # 5. Execute macro (emergency stop lifecycle is managed inside Invoke-MacroSequence)
        $success = $true
        $message = 'Macro completed successfully.'
        try {
            $execResult = Invoke-MacroSequence -MacroData $macroData -WindowHandle $WindowObject.WindowHandle
            $success = $execResult.Success
            $message = $execResult.Message
        } catch {
            $success = $false
            $message = "Macro execution failed: $_"
            Write-Error $message
        }

        Write-Output ([PSCustomObject]@{
            Success     = $success
            MacroName   = $MacroName
            WindowTitle = $WindowObject.WindowTitle
            Message     = $message
        })
    }
}
