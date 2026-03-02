# EmergencyStop.ps1
# Private helper for emergency-stop polling.
# Start-EmergencyStopMonitor and Stop-EmergencyStopMonitor are public functions
# located in the Public folder.

<#
.SYNOPSIS
    Executes one poll cycle checking whether an emergency-stop condition is met.

.DESCRIPTION
    Called by the System.Timers.Timer Elapsed handler in Start-EmergencyStopMonitor on each
    poll interval. Checks two independent emergency-stop triggers:

      1. Hotkey combo: every virtual key code in State.HotkeyVKeyCodes must be simultaneously
         held (high-order bit 0x8000 set for each).
      2. Mouse gesture: both mouse buttons (State.MouseGestureVKeyCodes, typically VK_LBUTTON
         0x01 and VK_RBUTTON 0x02) must be continuously held for State.MouseGestureRequiredPollCount
         consecutive polls. The hold counter is incremented each poll whilst both are held, and
         reset to 0 on release.

    On either trigger, the function:
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
                                               when $null. Shared by both hotkey and mouse gesture checks.
      MouseGestureEnabled          [bool]   - when $true, activates mouse gesture detection.
                                               Defaults to $false when absent from the hashtable.
      MouseGestureVKeyCodes        [int[]]  - VK_LBUTTON (0x01) and VK_RBUTTON (0x02).
                                               Not keyboard-layout-dependent.
      MouseGestureRequiredPollCount [int]   - consecutive polls where both buttons must be held
                                               before triggering. Computed as MouseGestureHoldDurationMs
                                               / PollIntervalMs in Start-EmergencyStopMonitor.
      MouseGestureCurrentPollCount  [int]   - running counter; incremented each poll whilst both
                                               buttons are held, reset to 0 on release. Mutated in-place.

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

    # Return early only when both detection mechanisms are inactive.
    # Checked here so the hotkey and gesture blocks can each run independently.
    $hotkeysConfigured = $null -ne $State.HotkeyVKeyCodes -and $State.HotkeyVKeyCodes.Count -gt 0
    $gestureEnabled    = $State.MouseGestureEnabled -eq $true

    if (-not $hotkeysConfigured -and -not $gestureEnabled) { return }

    # ── Hotkey detection ─────────────────────────────────────────────────────────────────
    if ($hotkeysConfigured) {
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
                -FunctionName 'Start-EmergencyStopMonitor'
            Write-Host "`e[31mEMERGENCY STOP TRIGGERED - automation halted. $(Get-LogCheckHint)`e[0m"
        }
    }

    # ── Mouse gesture detection (both buttons held for configured duration) ───────────────
    # Skipped when State.Stopped was set by the hotkey check above.
    if (-not $State.Stopped -and $gestureEnabled) {
        if ($null -ne $State.MouseGestureVKeyCodes -and $State.MouseGestureVKeyCodes.Count -gt 0) {
            $allButtonsHeld = $true
            foreach ($vKey in $State.MouseGestureVKeyCodes) {
                try {
                    $keyResult = if ($null -ne $State.GetKeyStateFn) {
                        & $State.GetKeyStateFn $vKey
                    } else {
                        [LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState($vKey)
                    }

                    if (($keyResult -band 0x8000) -eq 0) {
                        $allButtonsHeld = $false
                        break
                    }
                } catch {
                    Write-LastWarLog -Level Error `
                        -Message "Exception checking mouse button state for VKey $vKey : $_" `
                        -FunctionName 'Invoke-EmergencyStopPoll'
                    $State.MouseGestureCurrentPollCount = 0
                    return
                }
            }

            if ($allButtonsHeld) {
                $State.MouseGestureCurrentPollCount++
                if ($State.MouseGestureCurrentPollCount -ge $State.MouseGestureRequiredPollCount) {
                    $script:EmergencyStopRequested = $true
                    $State.Stopped = $true
                    if ($null -ne $State.Timer) { $State.Timer.Stop() }
                    Write-LastWarLog -Level Error `
                        -Message 'Emergency stop triggered by mouse gesture (both mouse buttons held).' `
                        -FunctionName 'Start-EmergencyStopMonitor'
                    Write-Host "`e[31mEMERGENCY STOP TRIGGERED - automation halted. $(Get-LogCheckHint)`e[0m"
                }
            } else {
                $State.MouseGestureCurrentPollCount = 0
            }
        }
    }
}

