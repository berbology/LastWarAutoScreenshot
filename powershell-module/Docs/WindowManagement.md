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
hotkey combination and sets a flag that aborts the automation loop cleanly.

### `Start-LWASEmergencyStopMonitor`

```powershell
# Use config defaults (Ctrl+Alt+Q at 100 ms)
Start-LWASEmergencyStopMonitor

# Override hotkey at call site via key names and poll interval
Start-LWASEmergencyStopMonitor -HotkeyKeyNames 'Ctrl+F12' -PollIntervalMs 200
```

- **Idempotent** - safe to call when already running; logs Info, returns
  without starting a second timer
- **Re-arming** - resets `$script:EmergencyStopRequested` to `$false` on
  every clean start

### `Stop-LWASEmergencyStopMonitor`

```powershell
try {
    Invoke-MacroSequence -Macro $macro -WindowHandle $handle
} finally {
    Stop-LWASEmergencyStopMonitor   # safe even if monitor is not running
}
```

Does **not** reset `$script:EmergencyStopRequested`. The flag stays `$true`
until the next `Start-LWASEmergencyStopMonitor` call.

### Stop flag lifecycle

| Action | Flag effect |
|--------|-------------|
| `Start-LWASEmergencyStopMonitor` (clean start) | Reset to `$false` |
| Hotkey held → `Invoke-EmergencyStopPoll` | Set to `$true` |
| `Invoke-MacroSequence` (checks before each action) | Reads; aborts if `$true` |
| `Stop-LWASEmergencyStopMonitor` | **Not modified** |

### Default hotkey

Default: `Ctrl+Alt+Q`, stored as the string `"Ctrl+Alt+Q"` in `EmergencyStop.HotkeyKeyNames`.
The key names are converted to virtual key codes at runtime via `ConvertFrom-HotkeyString`.

`#` is only a standalone key on UK keyboard layouts. On other layouts, reconfigure
`HotkeyKeyNames` via the app (**Configure module → Emergency stop settings**) or
by editing `ModuleConfig.json` directly:

```json
"HotkeyKeyNames": "Ctrl+Shift+P"
```

Accepted key name formats: `Ctrl`, `Shift`, `Alt`, `Win` (and `L`/`R` variants),
`A`–`Z`, `0`–`9`, `F1`–`F24`, `Esc`, `Enter`, `Tab`, `Space`, `Backspace`,
`Left`/`Right`/`Up`/`Down`, `Home`, `End`, `PageUp`, `PageDown`, `Insert`,
`Delete`, `Pause`, `CapsLock`, `NumLock`, `ScrollLock`, `Num0`–`Num9`,
`Num*`, `Num+`, `Num-`, `Num.`, `Num/`, and single OEM characters that your
keyboard layout produces without a modifier (e.g. `#` on UK).

See [Configuration.md](Configuration.md) for all `EmergencyStop.*` keys.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Keys held but automation doesn't stop | Key name not valid on your layout | Reconfigure `HotkeyKeyNames` to a key available without a modifier on your keyboard |
| `Invoke-MacroSequence` aborts immediately | Flag still `$true` from last run | Call `Start-LWASEmergencyStopMonitor` to re-arm |
| One of the hotkeys is held at startup | Flag set immediately on start | Release all keys before starting automation |
