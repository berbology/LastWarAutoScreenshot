## Window Management

Covers the three private helper functions used internally by the automation
workflow. You can call them directly in custom scripts if needed.

### `Set-WindowState`

Minimises or maximises a window by its handle.

```powershell
Set-WindowState -WindowHandle 123456 -State Minimize
Set-WindowState -WindowHandle 123456 -State Maximize

# Typical pattern: get handle from enumeration first
$target = Get-EnumeratedWindows |
    Where-Object { $_.ProcessName -eq 'LastWar' } |
    Select-Object -First 1
Set-WindowState -WindowHandle $target.WindowHandle -State Maximize
```

Returns `$true` on success, `$false` on failure. Errors print in red to the
console and are written to the configured log backend.

### `Set-WindowActive`

Brings a window to the foreground. Accepts a handle, window title, or PID.

```powershell
Set-WindowActive -WindowHandle 123456
Set-WindowActive -WindowName 'Last War: Survival'
Set-WindowActive -ProcessID 12345
```

Returns `$true`/`$false`. Windows may silently refuse foreground changes if a
UAC prompt or fullscreen app holds the foreground lock.

### `Start-WindowAndProcessMonitor`

Background polling monitor. Detects window closure or process exit and fires
a callback, prompting the user to retry or abort.

```powershell
$monitor = Start-WindowAndProcessMonitor `
    -WindowHandle 123456 `
    -ProcessId 12345 `
    -PollIntervalMs 1000 `
    -OnClosedOrExited {
        param($reason, $state)
        Write-Host "Window gone: $reason"
    }

# Run automation here...

# Always clean up
& $monitor.Stop
& $monitor.Cleanup
```

The returned object has `Timer`, `ProcessObject`, `Stop`, and `Cleanup`
properties. Always call both `Stop` and `Cleanup` on exit.

**Polling vs hooks:** Win32 event hooks (`SetWinEventHook`) fire on .NET
thread-pool threads where Pester mocks can't intercept them. Polling with
`System.Timers.Timer` is fully testable, simpler to maintain, and has
adequate detection latency for this use case.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Set-WindowActive` returns `$false`, no change | Foreground lock held (UAC, fullscreen) | Dismiss the blocking window and retry |
| `Set-WindowState` returns `$false` (Win32 error 0) | Stale handle - window closed | Re-enumerate with `Get-EnumeratedWindows` |
| Monitor fires late after game closes | `PollIntervalMs` too high | Lower it or wait for next tick |
| Red error, no Event Log entry | Event source not registered | Run once as Administrator; see [Logging.md](Logging.md) |

---

## Emergency Stop

Two exported functions manage the emergency-stop monitor. It polls for a
hotkey combination (or mouse gesture) and sets a flag that aborts the
automation loop cleanly.

### `Start-EmergencyStopMonitor`

```powershell
# Use config defaults (Ctrl+Shift+# at 100 ms)
Start-EmergencyStopMonitor

# Override
Start-EmergencyStopMonitor -HotkeyVKeyCodes @(0x11, 0x7B) -PollIntervalMs 200
```

- **Idempotent** - safe to call when already running; logs Info, returns
  without starting a second timer
- **Re-arming** - resets `$script:EmergencyStopRequested` to `$false` on
  every clean start

### `Stop-EmergencyStopMonitor`

```powershell
try {
    Start-AutomationSequence -WindowHandle $handle -RelativeX 0.5 -RelativeY 0.5
} finally {
    Stop-EmergencyStopMonitor   # safe even if monitor is not running
}
```

Does **not** reset `$script:EmergencyStopRequested`. The flag stays `$true`
until the next `Start-EmergencyStopMonitor` call.

### Stop flag lifecycle

| Action | Flag effect |
|--------|-------------|
| `Start-EmergencyStopMonitor` (clean start) | Reset to `$false` |
| Hotkey held → `Invoke-EmergencyStopPoll` | Set to `$true` |
| Mouse gesture held | Set to `$true` |
| `Start-AutomationSequence` (checks before/after move) | Reads; aborts if `$true` |
| `Stop-EmergencyStopMonitor` | **Not modified** |

### Default hotkey

Default: `Ctrl+Shift+#` — VKey codes `[0x11, 0x10, 0xDC]`.

`0xDC` is `#` on UK keyboards, `\` on standard US. Change via config or
parameter if your layout differs.

```powershell
# Ctrl + Pause/Break
Start-EmergencyStopMonitor -HotkeyVKeyCodes @(0x11, 0x13)
```

See [Configuration.md](Configuration.md) for all `EmergencyStop.*` keys.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Keys held but automation doesn't stop | VKey code mismatch for your layout | Check `GetAsyncKeyState` docs for your layout's code |
| Mouse gesture doesn't trigger | `MouseGestureEnabled` is `false` | Enable in config |
| Gesture triggers too slowly | `MouseGestureHoldDurationMs` too high | Reduce (e.g. `1500`) |
| `Start-AutomationSequence` aborts immediately | Flag still `$true` from last run | Call `Start-EmergencyStopMonitor` to re-arm |
| One of the hotkeys is held at startup | Flag set immediately on start | Release all keys before starting automation |
