[MouseControl Configuration]

The module supports detailed configuration for mouse movement to mimic human behaviour. All keys are set in the module config file (JSON/YAML).

**Config Keys:**

| Key                        | Type      | Default           | Description                                |
|----------------------------|-----------|-------------------|--------------------------------------------|
| MovementDurationRangeMs    | int[]     | [300, 600]        | Range for total move duration (ms)         |
| NumPoints                  | int       | 20                | Base number of Bezier points per move      |
| MicroPauseChance           | float     | 0.15              | Probability of micro-pause after each step |
| MicroPauseDurationRangeMs  | int[]     | [10, 40]          | Range for micro-pause duration (ms)        |
| OvershootEnabled           | bool      | true              | Enable overshoot/correction after move     |
| OvershootFactor            | float     | 0.12              | Scale for overshoot distance               |
| ClickPreDelayRangeMs       | int[]     | [50, 120]         | Random delay before click (ms)             |
| ClickPostDelayRangeMs      | int[]     | [60, 150]         | Random delay after click (ms)              |

**Example:**

```yaml
mouseControl:
  MovementDurationRangeMs: [300, 600]
  NumPoints: 20
  MicroPauseChance: 0.15
  MicroPauseDurationRangeMs: [10, 40]
  OvershootEnabled: true
  OvershootFactor: 0.12
  ClickPreDelayRangeMs: [50, 120]
  ClickPostDelayRangeMs: [60, 150]
```

## Cursor Target Region Parameter

The automation sequence supports defining a cursor target region using the `-Region` parameter. This allows random selection of a position within a user-defined area for each action, supporting both bounding box and circle formats.

### Box Format

Use a PSCustomObject with the following fields (all values between 0.0 and 1.0, relative to window size):

| Field           | Type   | Description                                 |
|-----------------|--------|---------------------------------------------|
| RelativeX       | double | Left edge of box (relative X, 0.0–1.0)      |
| RelativeY       | double | Top edge of box (relative Y, 0.0–1.0)       |
| RelativeWidth   | double | Width of box (relative, 0.0–1.0)            |
| RelativeHeight  | double | Height of box (relative, 0.0–1.0)           |

**Example:**

```powershell
$region = [PSCustomObject]@{
  RelativeX = 0.2
  RelativeY = 0.3
  RelativeWidth = 0.4
  RelativeHeight = 0.2
}
Start-AutomationSequence -WindowHandle $handle -Region $region
```

### Circle Format

Use a PSCustomObject with the following fields (all values between 0.0 and 1.0, relative to window size):

| Field            | Type   | Description                                 |
|------------------|--------|---------------------------------------------|
| RelativeCentreX  | double | X coordinate of circle center (0.0–1.0)     |
| RelativeCentreY  | double | Y coordinate of circle center (0.0–1.0)     |
| RelativeRadius   | double | Radius of circle (relative, 0.0–1.0)        |

**Example:**

```powershell
$region = [PSCustomObject]@{
  RelativeCentreX = 0.5
  RelativeCentreY = 0.5
  RelativeRadius = 0.15
}
Start-AutomationSequence -WindowHandle $handle -Region $region
```

### Usage Notes

- The `-Region` parameter is mutually exclusive with `-RelativeX` and `-RelativeY`.
- For each action, a random position is selected within the defined region.
- Values outside [0.0, 1.0] are clamped and invalid input returns `$null` with an error log.
- See [ProjectPlan.md](ProjectPlan.md) for algorithm details.

[Human-Like Mouse Movement]

Mouse movement is designed to avoid detection and feel natural:

- **Bezier Path Shaping:** Cursor moves along a smooth Bezier curve, not a straight line.
- **Ease-In/Ease-Out:** Step delays are longer at the start/end, shorter in the middle, creating acceleration and deceleration.
- **Jitter:** Each step has slight randomization in timing and position.
- **Micro-Pauses:** Random micro-pauses are inserted after steps, simulating human hesitation.
- **Overshoot/Correction:** Cursor overshoots the target, then corrects back, mimicking real mouse movement.

These behaviors are fully configurable via the keys above. See [ProjectPlan.md](ProjectPlan.md) for algorithm details.

# LastWar Auto Mouse Control & Screenshot Module

## Logging

For all details on error, diagnostic, and event logging—including log destinations, verbosity levels, configuration, and log format—see [docs/Logging.md](docs/Logging.md).

## Overview

This project is a PowerShell 7+ module designed to automate human-like mouse movements, clicks, drags, and screen captures within Windows applications—primarily targeting the game Last War: Survival (`LastWar.exe`). The module uses window-relative coordinates for reliable automation across different display configurations and is extensible for other games or applications.

**Note:** This module is designed for Windows 11 (64-bit) where the target game is supported. Only one instance can run at a time since the game supports single-instance execution only.

## Features

- **Window Management:** Enumerate all open windows (including minimized/background), select target window via interactive console menu, automatically bring to front and restore if minimized
  - Uses Win32 API (`EnumWindows`, `GetWindowText`, `IsWindowVisible`, `IsIconic`, `GetForegroundWindow`) via P/Invoke for reliable window enumeration and selection
  - Interactive menu supports sorting, filtering, and arrow-key navigation
  - Active window detection to highlight the currently focused application
  - Proper memory management with delegate lifetime handling to prevent garbage collection issues
  - Window and process monitoring uses polling (`System.Timers.Timer`) rather than Win32 event hooks (`SetWinEventHook`). Hooks were rejected because their callbacks run on .NET thread-pool threads where PowerShell mocks cannot intercept them, making hook-based code untestable with Pester; polling is simpler, fully testable, and sufficient for the detection latency required here
- **Emergency Stop:** Configurable hotkey combination (default: `Ctrl+Shift+#` on UK keyboards) or hold both mouse buttons for 3 seconds to immediately abort automation
- **Window-Relative Coordinates:** All mouse positions are relative to the target window for consistency across different screen configurations
- **Human-Like Interaction:** Configurable mouse movement with randomized delays, curved paths, and variable timing to mimic human behaviour and avoid detection as automated input
- **Flexible Target Definition:** Define cursor targets as bounding boxes or circles with randomized selection within the defined area
- **Interactive Recording:** GUI-based recording of mouse actions (move, click, drag) with automatic generation of user configuration files
- **Multiple Config Formats:** Support for JSON and YAML configuration files; user settings files created after recording
- **Scheduled Execution:** Windows Task Scheduler integration for automated, repeatable execution with configurable intervals, randomization, and duration
- **Smart Screenshot Capture:** User-defined regions captured in PNG/JPEG formats with configurable naming patterns
- **Screenshot Similarity Detection:** Pixel-based comparison (>98% match threshold) to detect end of scrolling lists without requiring OCR
- **Local Storage Management:** Configurable storage limit (default 2GB) with GUI progress indicator and user prompts when limits reached
- **Robust Error Handling:** Exponential backoff with jitter for retry logic, comprehensive error logging in debug mode
- **Azure Blob Integration (Planned):** SAS-based upload with retry logic for cloud-based OCR processing

## Requirements

- Windows 11 (64-bit)
- PowerShell 7.0 or higher
- Minimum 16GB RAM (recommended for gaming PC)
- No external dependencies required for core functionality (uses Windows API and .NET)
  - Window enumeration uses User32.dll via P/Invoke
  - .NET CLR handles memory management for Win32 API interop
- Administrator privileges may be required for Windows Event Logging

## Getting Started

1. Clone this repository:

   ```powershell
   git clone https://github.com/berbology/LastWarAutoScreenshot.git
   cd LastWarAutoScreenshot
   ```

2. Install the module to your PowerShell module path:

   ```powershell
   # Option 1: Install for current user (recommended)
   $UserModulePath = "$HOME\Documents\PowerShell\Modules\LastWarScreenshot"
   Copy-Item -Path .\src\LastWarAutoClickScreenshot -Destination $UserModulePath -Recurse -Force
   
   # Option 2: Install system-wide (requires admin)
   $SystemModulePath = "$env:ProgramFiles\PowerShell\Modules\LastWarScreenshot"
   Copy-Item -Path .\src\LastWarAutoClickScreenshot -Destination $SystemModulePath -Recurse -Force
   ```

3. Import and verify the module:

   ```powershell
   Import-Module LastWarScreenshot
   Get-Module LastWarScreenshot
   ```

4. Launch the GUI to record and configure your automation sequence

5. Configure scheduling via Windows Task Scheduler or run manually as needed

## Window State Management

Three private functions handle window state. They are used internally by the automation workflow and can also be called directly in custom scripts.

### `Set-WindowState`

Minimises or maximises a window by its handle.

```powershell
# Minimise a window
Set-WindowState -WindowHandle 123456 -State Minimize

# Maximise using a handle obtained from Get-EnumeratedWindows
$target = Get-EnumeratedWindows | Where-Object { $_.ProcessName -eq 'LastWar' } | Select-Object -First 1
Set-WindowState -WindowHandle $target.WindowHandle -State Maximize
```

Returns `$true` on success, `$false` on failure. Errors are printed in red to the console and written to the configured log backend.

### `Set-WindowActive`

Brings a window to the foreground. Accepts a handle, window title, or process ID — whichever is most convenient.

```powershell
# By handle
Set-WindowActive -WindowHandle 123456

# By window title
Set-WindowActive -WindowName 'Last War: Survival'

# By process ID
Set-WindowActive -ProcessID 12345
```

Returns `$true` on success, `$false` on failure. Windows may silently refuse foreground changes if another application currently holds the foreground lock (e.g., a UAC prompt is open). The Win32 error code is captured and logged automatically.

### `Start-WindowAndProcessMonitor`

Starts continuous background monitoring of a window handle and process. On detection of window closure or process exit it prompts the user to retry monitoring or abort, then invokes the `OnClosedOrExited` callback if the user aborts.

```powershell
$monitor = Start-WindowAndProcessMonitor `
    -WindowHandle 123456 `
    -ProcessId 12345 `
    -PollIntervalMs 1000 `
    -OnClosedOrExited {
        param($reason, $state)
        Write-Host "Monitoring ended: $reason"
    }

# ... automation runs here ...

# Always stop and clean up when done
& $monitor.Stop
& $monitor.Cleanup
```

The returned object exposes four properties: `Timer`, `ProcessObject`, `Stop` (scriptblock), and `Cleanup` (scriptblock). Always call both `Stop` and `Cleanup` when the workflow ends to release the underlying timer and process object.

**Polling interval:** Default is 1000 ms. Lower values detect closure faster at the cost of slightly higher CPU polling overhead. A range of 500–2000 ms is practical for most use cases.

### Troubleshooting: Window State

| Symptom                                                 | Likely Cause                                          | Resolution                                                                              |
|:--------------------------------------------------------|:------------------------------------------------------|:----------------------------------------------------------------------------------------|
| `Set-WindowActive` returns `$false` (no visible change) | Foreground lock held by another app (UAC, fullscreen) | Dismiss blocking window, retry                                                          |
| `Set-WindowState` returns `$false` (Win32 error 0)      | Handle is stale (window closed since enumeration)     | Re-enumerate with `Get-EnumeratedWindows` for a fresh handle                            |
| Monitor retry/abort prompt delayed after game closes    | `PollIntervalMs` set high; fires on next poll tick    | Lower `PollIntervalMs` or wait for next tick                                            |
| Red error in console, no log entry                      | `Write-EventLog` failed (event source not registered) | Run module as Administrator once to register event source; see [Logging.md](Logging.md) |

## Emergency Stop

Two public functions manage the emergency-stop background monitor. The monitor polls for a configurable hotkey combination; when all keys are held simultaneously it sets an internal flag that causes the automation loop to abort cleanly.

### `Start-EmergencyStopMonitor`

Starts a background `System.Timers.Timer` that polls for the configured hotkey combination every `PollIntervalMs` milliseconds.

```powershell
# Use config defaults (Ctrl+Shift+# at 100 ms polling)
$monitor = Start-EmergencyStopMonitor

# Override to Ctrl+F12 at 200 ms
$monitor = Start-EmergencyStopMonitor -HotkeyVKeyCodes @(0x11, 0x7B) -PollIntervalMs 200
```

**Idempotency:** calling `Start-EmergencyStopMonitor` while the monitor is already running is safe — it logs an Info message and returns `$null` without creating a second timer.

**Re-arming:** `Start-EmergencyStopMonitor` resets `$script:EmergencyStopRequested` to `$false` on every clean start, so a new automation sequence can proceed immediately after calling it.

The returned object exposes two scriptblocks: `Stop` (sets the internal Stopped flag and stops the timer) and `Cleanup` (disposes the timer). Use `Stop-EmergencyStopMonitor` for full clean-up in normal workflows.

### `Stop-EmergencyStopMonitor`

Stops and disposes the background timer. Safe to call when no monitor is active (does not throw).

```powershell
# Normal pattern — always stop in a finally block
try {
    $result = Start-AutomationSequence -WindowHandle $handle -RelativeX 0.5 -RelativeY 0.5
} finally {
    Stop-EmergencyStopMonitor
}
```

**Important:** `Stop-EmergencyStopMonitor` does **not** reset `$script:EmergencyStopRequested`. After a triggered stop, the flag remains `$true` until the next call to `Start-EmergencyStopMonitor` (which resets it). Any code reading the flag between a stop and a restart will correctly see the previous stop.

### `$script:EmergencyStopRequested` — the stop flag

| Action                                        | Effect on flag        |
|:----------------------------------------------|:----------------------|
| `Start-EmergencyStopMonitor` (clean start)    | Reset to `$false`     |
| Hotkey held → `Invoke-EmergencyStopPoll`      | Set to `$true`        |
| Mouse gesture held → `Invoke-EmergencyStopPoll` | Set to `$true`      |
| `Start-AutomationSequence` (checks before/after move) | Reads flag, aborts if `$true` |
| `Stop-EmergencyStopMonitor`                   | **Not modified**       |

### Default hotkey and keyboard-layout caveat

| Key     | Virtual key code | British value | Notes                                                                 |
|:--------|:-----------------|:--------------|:----------------------------------------------------------------------|
| Ctrl    | `0x11` (17)      | ✓             |                                                                       |
| Shift   | `0x10` (16)      | ✓             |                                                                       |
| `#`     | `0xDC` (220)     | UK `#` key    | On standard US keyboards `0xDC` maps to `\`. Adjust via config.      |

To change the hotkey, set `EmergencyStop.HotkeyVKeyCodes` in the module configuration file, or pass `-HotkeyVKeyCodes` directly:

```powershell
# Ctrl + Pause/Break (0x11, 0x13)
Start-EmergencyStopMonitor -HotkeyVKeyCodes @(0x11, 0x13)
```

### Emergency Stop configuration keys

| Key                                    | Type    | Default              | Description                                                          |
|:---------------------------------------|:--------|:---------------------|:---------------------------------------------------------------------|
| `EmergencyStop.AutoStart`              | bool    | `true`               | Auto-start the monitor when `Start-AutomationSequence` runs          |
| `EmergencyStop.HotkeyVKeyCodes`        | int[]   | `[17, 16, 220]`      | VKey codes that must all be held simultaneously to trigger stop      |
| `EmergencyStop.PollIntervalMs`         | int     | `100`                | How often to check key/button state (milliseconds)                   |
| `EmergencyStop.MouseGestureEnabled`    | bool    | `true`               | Enable the hold-both-buttons gesture as an additional trigger        |
| `EmergencyStop.MouseGestureHoldDurationMs` | int | `3000`               | Duration in milliseconds both buttons must be held before triggering |

**Example configuration entry (WindowConfig.json):**

```json
"EmergencyStop": {
  "AutoStart": true,
  "HotkeyVKeyCodes": [17, 16, 220],
  "PollIntervalMs": 100,
  "MouseGestureEnabled": true,
  "MouseGestureHoldDurationMs": 3000
}
```

### Troubleshooting: Emergency Stop

| Symptom                                        | Likely Cause                                         | Resolution                                                      |
|:-----------------------------------------------|:-----------------------------------------------------|:----------------------------------------------------------------|
| Automation does not stop when keys held        | `HotkeyVKeyCodes` mismatch for keyboard layout       | Check your layout; use `GetAsyncKeyState` docs to find VK codes |
| Mouse gesture does not trigger stop            | `MouseGestureEnabled` is `false` in config           | Set `EmergencyStop.MouseGestureEnabled` to `true`               |
| Mouse gesture triggers too slowly              | `MouseGestureHoldDurationMs` too high                | Reduce `EmergencyStop.MouseGestureHoldDurationMs` (e.g. 1500)   |
| Monitor starts but immediately triggers        | One of the configured keys is held at start          | Release all keys before starting automation                     |
| `Start-AutomationSequence` aborts immediately  | `$script:EmergencyStopRequested` still `$true`       | Call `Start-EmergencyStopMonitor` to reset the flag             |
| Red message in console, polling feels slow     | `PollIntervalMs` too high                            | Reduce `EmergencyStop.PollIntervalMs` (e.g. to 50 ms)          |

## Roadmap

See [docs/ProjectPlan.md](docs/ProjectPlan.md) for the full project plan and upcoming features.

## License

MIT License (see LICENSE file)

## Disclaimer

**Anti-Cheat Warning:**
Automating mouse or keyboard input in games or other software may violate terms of service and can trigger anti-cheat systems, potentially resulting in account suspension or bans. Use this tool at your own risk. The authors are not responsible for any consequences arising from its use.

This tool is intended for personal automation and testing purposes. Use responsibly and in accordance with the terms of service of any software you automate.

## Testing & CI

Unit testing is performed using the Pester framework. Continuous Integration/Continuous Deployment (CI/CD) setup is under consideration and will be documented once finalized.

## Error Handling

See [docs/Logging.md](docs/Logging.md) for all error and logging details, including error recovery and emergency stop logging.

## Configuration

### Saving and Retrieving Window Configuration

The module automatically saves and loads the selected window configuration (such as process name, window title, and handle) to a configuration file for later use. By default, this file is stored at:

  $env:APPDATA\LastWarAutoScreenshot\WindowConfig.json

This location follows Windows and PowerShell best practices for user-specific configuration data. The file is created automatically when you save a window configuration using the provided functions or GUI.

#### Custom Configuration Path

If you wish to save or load the configuration from a different location, you can specify a custom path using the `-ConfigurationPath` parameter with the relevant commands (e.g., `Save-ModuleConfiguration`, `Get-ModuleConfiguration`, or `Test-ModuleConfigurationExists`).

**Example:**

```powershell
$window = Get-EnumeratedWindows | Select-TargetWindowFromMenu
Save-ModuleConfiguration -WindowObject $window -ConfigurationPath "C:\MyConfigs\CustomWindowConfig.json"

# Later, to load from the same custom path:
$config = Get-ModuleConfiguration -ConfigurationPath "C:\MyConfigs\CustomWindowConfig.json"
```

If no path is specified, the default location in `$env:APPDATA` is always used.

The module supports both JSON and YAML configuration files. Configuration files are automatically generated after recording actions via the GUI and can be manually edited, saved, or imported.

**Basic Configuration Structure:**

```yaml
version: "1.0"
settings:
  emergencyStop:
    hotkey: "Ctrl+Shift+Esc"
    mouseHoldDuration: 3000
window:
  processName: "LastWar.exe"
  bringToFront: true
  restoreIfMinimized: true
actions:
  - name: "Open menu"
    type: "click"
    target:
      type: "rectangle"
      x: 100  # Window-relative coordinates
      y: 200
      width: 50
      height: 30
    humanLike:
      enabled: true
      movementSteps: 20-40
      delayMs: 10-30
screenshots:
  localPath: "./screenshots"
  maxStorageGB: 2.0
  similarityThreshold: 98.0
logging:
  mode: "Verbose"
  debugIncludeVariables: true
```

See example configuration files in the `examples/` directory for complete reference.

## Scheduling

The module integrates with Windows Task Scheduler for automated execution. Configuration options include:

- Start date and time
- Repeat interval (e.g., every 6 hours)
- Repeat duration (fixed period or indefinitely)
- Random delay before task start (0-120 minutes for variability)
- Stop task if runs longer than specified duration
- Expire task after specified date

Schedules can be configured via the GUI or by manually creating Task Scheduler triggers.

## Storage Management

Screenshot storage is managed with user-configurable limits:

- **Default Limit:** 2GB of local storage for screenshots
- **GUI Indicator:** Progress bar shows current usage in GB
- **Limit Reached:** User prompted with options to increase limit or perform drive cleanup
- **Format:** PNG or JPEG, configurable per action
- **Naming:** Configurable patterns with timestamp and index placeholders

Typical usage: Hundreds of screenshots per day, suitable for gaming PCs with adequate storage.
