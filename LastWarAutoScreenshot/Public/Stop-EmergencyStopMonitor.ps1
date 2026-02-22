function Stop-EmergencyStopMonitor {
    <#
    .SYNOPSIS
        Stops and disposes the emergency-stop background timer.

    .DESCRIPTION
        Stops the System.Timers.Timer managed by $script:EmergencyStopTimer, disposes it, and
        sets the variable to $null so that a subsequent call to Start-EmergencyStopMonitor will
        start a fresh timer.

        Calling this function when no monitor is currently running is safe and does nothing
        (does not throw).

        IMPORTANT — re-arming behaviour:
        This function deliberately does NOT reset $script:EmergencyStopRequested.  If an
        emergency stop was triggered, the flag remains $true after this call.  Any code that
        checks the flag (e.g. Start-AutomationSequence) will see the stop and abort cleanly.
        To re-arm the monitor for a new sequence, call Start-EmergencyStopMonitor — it resets
        the flag as part of its own start sequence.

    .EXAMPLE
        Stop-EmergencyStopMonitor

    .EXAMPLE
        # Typical pattern: always stop in a finally block
        try {
            $result = Start-AutomationSequence -WindowHandle $handle -RelativeX 0.5 -RelativeY 0.5
        } finally {
            Stop-EmergencyStopMonitor
        }

    .NOTES
        Does NOT reset $script:EmergencyStopRequested — see description above.
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
            -FunctionName 'Stop-EmergencyStopMonitor'
    }
    # If $script:EmergencyStopTimer is already $null, silently do nothing.
    # $script:EmergencyStopRequested is intentionally NOT reset here.
}
