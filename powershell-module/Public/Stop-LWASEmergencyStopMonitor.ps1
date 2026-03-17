function Stop-LWASEmergencyStopMonitor {
    <#
    .SYNOPSIS
        Stops and disposes the emergency-stop background timer.

    .DESCRIPTION
        Stops the System.Timers.Timer managed by $script:EmergencyStopTimer, disposes it, and
        sets the variable to $null so that a subsequent call to Start-LWASEmergencyStopMonitor will
        start a fresh timer.

        Calling this function when no monitor is currently running is safe and does nothing
        (does not throw).

        IMPORTANT - re-arming behaviour:
        This function deliberately does NOT reset $script:EmergencyStopRequested.  If an
        emergency stop was triggered, the flag remains $true after this call.  Any code that
        checks the flag (e.g. Invoke-MacroSequence) will see the stop and abort cleanly.
        To re-arm the monitor for a new sequence, call Start-LWASEmergencyStopMonitor - it resets
        the flag as part of its own start sequence.

    .EXAMPLE
        Stop-LWASEmergencyStopMonitor

    .EXAMPLE
        # Typical pattern: always stop in a finally block
        try {
            $result = Invoke-MacroSequence -MacroData $macroData -WindowHandle $handle
        } finally {
            Stop-LWASEmergencyStopMonitor
        }

    .NOTES
        Does NOT reset $script:EmergencyStopRequested - see description above.
        This is a public function exported from the module.
    #>
    [CmdletBinding()]
    param()

    if ($null -ne $script:EmergencyStopTimer) {
        try { $script:EmergencyStopTimer.Stop() }    catch {}
        try { $script:EmergencyStopTimer.Dispose() } catch {}
        $script:EmergencyStopTimer = $null
        Write-LastWarLog -Level Info `
            -Message 'Emergency stop monitor stopped.' `
            -FunctionName 'Stop-LWASEmergencyStopMonitor'
    }
    # If $script:EmergencyStopTimer is already $null, silently do nothing.
    # $script:EmergencyStopRequested is intentionally NOT reset here.
}

