# EmergencyStop.ps1
# Private helper for emergency-stop polling.
# Start-LWASEmergencyStopMonitor and Stop-LWASEmergencyStopMonitor are public functions
# located in the Public folder.

<#
.SYNOPSIS
    Executes one poll cycle checking whether an emergency-stop condition is met.

.DESCRIPTION
    Called by the System.Timers.Timer Elapsed handler in Start-LWASEmergencyStopMonitor on each
    poll interval. Checks one emergency-stop trigger:

      Hotkey combo: every virtual key code in State.HotkeyVKeyCodes must be simultaneously
      held (high-order bit 0x8000 set for each).

    On trigger, the function:
      - Sets $script:EmergencyStopRequested = $true in the module scope
      - Sets $State.Stopped = $true
      - Stops the timer
      - Logs an Error via Write-LastWarLog
      - Writes a red ANSI console message

    Extracted from the timer callback so it can be called synchronously in Pester tests -
    timer thread-pool callbacks are invisible to PowerShell mocks.

.PARAMETER State
    Hashtable with the following keys:
      Stopped                      [bool]   - set to $true to suppress further polls
      Timer           [System.Timers.Timer] - stopped when emergency stop triggers
      HotkeyVKeyCodes              [int[]]  - virtual key codes that must all be held simultaneously
      GetKeyStateFn            [ScriptBlock] - injectable mock; receives vKey as first arg.
                                               Defaults to [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState
                                               when $null.

.NOTES
    Win32 RegisterHotKey was considered as an alternative but rejected:
      1. Testability: hot-key messages arrive on a message-pump thread; Pester mocks cannot
         intercept them.
      2. Complexity: RegisterHotKey requires a dedicated message loop and clean-up of the
         registered hot-key on exit.
    Polling via System.Timers.Timer is simple, fully testable, and sufficient for the
    detection latency required here.

    This is a private function not exported from the module.
#>
function Invoke-EmergencyStopPoll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.Stopped) { return }

    $hotkeysConfigured = $null -ne $State.HotkeyVKeyCodes -and $State.HotkeyVKeyCodes.Count -gt 0

    if (-not $hotkeysConfigured) { return }

    # ── Hotkey detection ─────────────────────────────────────────────────────────────────
    $allKeysHeld = $true
    foreach ($vKey in $State.HotkeyVKeyCodes) {
        try {
            $keyResult = if ($null -ne $State.GetKeyStateFn) {
                & $State.GetKeyStateFn $vKey
            } else {
                [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState($vKey)
            }

            # High-order bit (0x8000) set means the key is currently held down.
            if (($keyResult -band 0x8000) -eq 0) {
                $allKeysHeld = $false
                break
            }
        } catch {
            Write-LastWarLog -Level Error `
                -Message "Exception checking key state for VKey $vKey : $_" `
                -FunctionName 'Invoke-EmergencyStopPoll'
            return
        }
    }

    if ($allKeysHeld) {
        $script:EmergencyStopRequested = $true
        $State.Stopped = $true
        if ($null -ne $State.Timer) { $State.Timer.Stop() }
        Write-LastWarLog -Level Error `
            -Message 'Emergency stop triggered by hotkey combination.' `
            -FunctionName 'Start-LWASEmergencyStopMonitor'
        Write-Host "`e[31mEMERGENCY STOP TRIGGERED - automation halted. $(Get-LogCheckHint)`e[0m"
    }
}

