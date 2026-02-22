function Start-EmergencyStopMonitor {
    <#
    .SYNOPSIS
        Starts a background timer that polls for the configured emergency-stop hotkey combination.

    .DESCRIPTION
        Creates a System.Timers.Timer (AutoReset) that fires every PollIntervalMs milliseconds.
        On each tick, Invoke-EmergencyStopPoll checks two independent emergency-stop triggers:
          1. Hotkey combo: all keys in HotkeyVKeyCodes held simultaneously.
          2. Mouse gesture: both mouse buttons (VK_LBUTTON 0x01, VK_RBUTTON 0x02) held
             continuously for MouseGestureHoldDurationMs milliseconds.
        On either trigger, $script:EmergencyStopRequested is set to $true, the timer is
        stopped, an Error is logged, and a red ANSI message is written to the console.

        The function is idempotent: if the monitor is already running (i.e.
        $script:EmergencyStopTimer.Enabled is $true), a second call logs an informational message
        and returns without creating a new timer.

        On a clean start, $script:EmergencyStopRequested is always reset to $false so that an
        automation sequence that was previously stopped can be re-armed simply by calling
        Start-EmergencyStopMonitor again (after Stop-EmergencyStopMonitor has been called to
        clean up the previous timer).

    .PARAMETER PollIntervalMs
        How often to poll for the hotkey, in milliseconds. Reads EmergencyStop.PollIntervalMs
        from the module configuration when omitted. Get-ModuleConfiguration always returns a
        valid config (creating one with defaults on first run), so no separate fallback is
        required here.

    .PARAMETER HotkeyVKeyCodes
        Array of virtual key codes that must all be held simultaneously to trigger the stop.
        Reads EmergencyStop.HotkeyVKeyCodes from the module configuration when omitted.
        Get-ModuleConfiguration always returns a valid config (creating one with defaults on
        first run), so no separate fallback is required here.

        Virtual key code reference:
          0x11 (17)  = VK_CONTROL
          0x10 (16)  = VK_SHIFT
          0xDC (220) = VK_OEM_5  — '#' on UK QWERTY, '\' on standard US layout.
                                   Adjust this value to match your keyboard layout.

    .OUTPUTS
        PSCustomObject with scriptblock properties:
          Stop    — sets State.Stopped = $true and stops the timer (does NOT null the variable
                    or dispose the timer — use Stop-EmergencyStopMonitor for full clean-up).
          Cleanup — safely stops and disposes the timer.

        Returns $null (with Info logged) when called while already running.

    .EXAMPLE
        $monitor = Start-EmergencyStopMonitor
        # ... automation runs ...
        Stop-EmergencyStopMonitor

    .EXAMPLE
        # Override hotkey to Ctrl+F12 (0x11, 0x7B)
        Start-EmergencyStopMonitor -HotkeyVKeyCodes @(0x11, 0x7B) -PollIntervalMs 200

    .NOTES
        Why polling instead of Win32 RegisterHotKey:
          1. Testability: RegisterHotKey messages arrive on a dedicated message-pump thread.
             Pester mocks are scoped to the calling runspace and cannot intercept callbacks
             on other threads, making hot-key registration untestable with Pester.
          2. Complexity: RegisterHotKey requires a message loop and explicit UnregisterHotKey
             on exit — significantly more scaffolding for no functional benefit at the poll
             rates used here.
          Polling via System.Timers.Timer is simple, fully testable, and sufficient.

        Re-arming: Stop-EmergencyStopMonitor does NOT reset $script:EmergencyStopRequested.
        Callers must reset the flag manually (e.g. $script:EmergencyStopRequested = $false
        inside InModuleScope) before calling Start-EmergencyStopMonitor again if they want
        the automation loop to proceed after a previous stop.
        Start-EmergencyStopMonitor itself resets the flag on each clean start, which is
        sufficient for the normal workflow where the monitor is started fresh per sequence.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$PollIntervalMs,

        [Parameter()]
        [int[]]$HotkeyVKeyCodes
    )

    # ── Idempotency check ────────────────────────────────────────────────────────
    if ($null -ne $script:EmergencyStopTimer) {
        $timerRunning = $false
        try { $timerRunning = $script:EmergencyStopTimer.Enabled } catch {}

        if ($timerRunning) {
            Write-LastWarLog -Level Info `
                -Message 'Emergency stop monitor is already running — ignoring duplicate start.' `
                -FunctionName 'Start-EmergencyStopMonitor'
            return $null
        }

        # The timer exists but is stopped (e.g. it fired and triggered an emergency stop,
        # but Stop-EmergencyStopMonitor was not yet called).  Dispose the stale timer and
        # start a fresh one so state is clean.
        try { $script:EmergencyStopTimer.Dispose() } catch {}
        $script:EmergencyStopTimer = $null
    }

    # ── Resolve effective parameter values ───────────────────────────────────────
    # Get-ModuleConfiguration is the single source of truth for all defaults.
    # It never returns $null — if no config file exists it creates one with defaults.
    $config = Get-ModuleConfiguration
    $effectivePollIntervalMs  = [int]$config.EmergencyStop.PollIntervalMs
    $effectiveHotkeyVKeyCodes = [int[]]$config.EmergencyStop.HotkeyVKeyCodes

    # Explicitly-supplied parameters always win over config values.
    if ($PSBoundParameters.ContainsKey('PollIntervalMs'))  { $effectivePollIntervalMs  = $PollIntervalMs  }
    if ($PSBoundParameters.ContainsKey('HotkeyVKeyCodes')) { $effectiveHotkeyVKeyCodes = $HotkeyVKeyCodes }

    # Mouse gesture settings are always read from config (no parameter overrides).
    $mouseGestureEnabled       = [bool]$config.EmergencyStop.MouseGestureEnabled
    $mouseGestureHoldDurationMs = [int]$config.EmergencyStop.MouseGestureHoldDurationMs

    # ── Reset the stop flag and build state ─────────────────────────────────────
    $script:EmergencyStopRequested = $false

    $state = @{
        Stopped                       = $false
        Timer                         = $null
        HotkeyVKeyCodes               = $effectiveHotkeyVKeyCodes
        GetKeyStateFn                 = $null   # $null → real GetAsyncKeyState API; scriptblock → mock/test
        # VK_LBUTTON (0x01) and VK_RBUTTON (0x02) are fixed codes, not keyboard-layout-dependent.
        MouseGestureEnabled           = $mouseGestureEnabled
        MouseGestureVKeyCodes         = @(0x01, 0x02)
        MouseGestureRequiredPollCount = [int][Math]::Ceiling($mouseGestureHoldDurationMs / $effectivePollIntervalMs)
        MouseGestureCurrentPollCount  = 0
    }

    # ── Create and start the timer ───────────────────────────────────────────────
    $timer = [System.Timers.Timer]::new($effectivePollIntervalMs)
    $timer.AutoReset = $true
    $state.Timer = $timer
    $script:EmergencyStopTimer = $timer

    $timer.add_Elapsed({
        try {
            Invoke-EmergencyStopPoll -State $state
        } catch {
            # Ultimate safety net — never let an unhandled exception escape the Elapsed handler.
        }
    }.GetNewClosure())

    $timer.Start()

    # ── Return monitor object ────────────────────────────────────────────────────
    return [PSCustomObject]@{
        Stop    = { $state.Stopped = $true; $state.Timer.Stop() }.GetNewClosure()
        Cleanup = {
            try { $state.Timer.Stop() }    catch {}
            try { $state.Timer.Dispose() } catch {}
        }.GetNewClosure()
    }
}
