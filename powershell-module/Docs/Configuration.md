## Configuration Reference

All settings live in `$env:APPDATA\LastWarAutoScreenshot\ModuleConfig.json`.
The file is created automatically with defaults on first run - you generally
won't need to edit it by hand; use `Start-LastWarAutoScreenshot` → Configure
module instead.

### Config file location

| Scenario | Path |
|----------|------|
| Default (all users) | `$env:APPDATA\LastWarAutoScreenshot\ModuleConfig.json` |
| Custom path | Pass `-ConfigurationPath` to `Get-ModuleConfiguration` / `Save-ModuleConfiguration` |

```powershell
# Load from a custom path
$config = Get-ModuleConfiguration -ConfigurationPath 'C:\MyConfigs\custom.json'

# Save to a custom path
Save-ModuleConfiguration -WindowObject $window -ConfigurationPath 'C:\MyConfigs\custom.json'
```

---

### MouseControl

Controls how the cursor moves to avoid looking like a bot.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `EasingEnabled` | bool | `true` | Slow at start/end, fast mid-path |
| `OvershootEnabled` | bool | `true` | Overshoot target then correct back |
| `OvershootFactor` | double | `0.1` | Overshoot scale (0.0-1.0) |
| `MicroPausesEnabled` | bool | `true` | Random hesitation pauses |
| `MicroPauseChance` | double | `0.2` | Probability of pause per step (0.0-1.0) |
| `MinMicroPauseDurationMs` | int | `20` | Minimum micro-pause duration (ms) |
| `MaxMicroPauseDurationMs` | int | `80` | Maximum micro-pause duration (ms) |
| `JitterEnabled` | bool | `true` | Slight path wobble |
| `JitterRadiusPx` | int | `2` | Wobble radius in pixels (0-20) |
| `BezierControlPointOffsetFactor` | double | `0.3` | Curve sharpness (0.0-2.0) |
| `MovementDurationRangeMs` | int[] | `[200, 600]` | Total move time range (ms) |
| `ClickDownDurationRangeMs` | int[] | `[50, 150]` | Mouse-down hold time range (ms) |
| `ClickPreDelayRangeMs` | int[] | `[50, 200]` | Delay before click (ms) |
| `ClickPostDelayRangeMs` | int[] | `[100, 300]` | Delay after click (ms) |
| `PathPointCount` | int | `20` | Base Bezier point count (5-200) |

**Example (ModuleConfig.json excerpt):**

```json
"MouseControl": {
  "EasingEnabled": true,
  "OvershootEnabled": true,
  "OvershootFactor": 0.1,
  "MicroPausesEnabled": true,
  "MicroPauseChance": 0.2,
  "MinMicroPauseDurationMs": 20,
  "MaxMicroPauseDurationMs": 80,
  "JitterEnabled": true,
  "JitterRadiusPx": 2,
  "MovementDurationRangeMs": [200, 600],
  "ClickDownDurationRangeMs": [50, 150],
  "PathPointCount": 20
}
```

#### Cursor target regions

`Start-AutomationSequence` accepts a `-Region` parameter so each click
lands at a random point inside a defined area rather than a fixed coordinate.

**Box** (uniform random within rectangle):

```powershell
$region = [PSCustomObject]@{
    RelativeX      = 0.2   # left edge (0.0-1.0, relative to window width)
    RelativeY      = 0.3   # top edge
    RelativeWidth  = 0.4   # width
    RelativeHeight = 0.2   # height
}
Start-AutomationSequence -WindowHandle $handle -Region $region
```

**Circle** (uniform random within disc):

```powershell
$region = [PSCustomObject]@{
    RelativeCentreX = 0.5   # centre X
    RelativeCentreY = 0.5   # centre Y
    RelativeRadius  = 0.15  # radius
}
Start-AutomationSequence -WindowHandle $handle -Region $region
```

`-Region` is mutually exclusive with `-RelativeX`/`-RelativeY`. All values
must be in `[0.0, 1.0]`; out-of-range input logs an error and returns `$null`.

---

### EmergencyStop

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `AutoStart` | bool | `true` | Start monitor automatically with `Start-AutomationSequence` |
| `HotkeyVKeyCodes` | int[] | `[17, 16, 220]` | Ctrl+Shift+# (UK layout) |
| `PollIntervalMs` | int | `100` | Polling frequency in ms (10-5000) |
| `MouseGestureEnabled` | bool | `true` | Hold both mouse buttons as a stop trigger |
| `MouseGestureHoldDurationMs` | int | `3000` | Hold duration to trigger (500-30000 ms) |

The `#` key is `0xDC` on UK layouts. On a US layout `0xDC` is `\` - adjust
`HotkeyVKeyCodes` to suit your keyboard. See
[WindowManagement.md](WindowManagement.md) for full emergency stop details.

---

### Screenshots

Configured via the Storage & Log Info screen in the app.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `StoragePath` | string | `""` | Folder where screenshots are saved. Empty = not configured |
| `MaxStorageGB` | double | `2.0` | Storage cap before the app warns you (0.1-2048 GB) |

When `StoragePath` is empty the storage info screen prompts you to configure
it. The app shows a usage chart and warns at 90% capacity.

**Example:**

```json
"Screenshots": {
  "StoragePath": "C:\\GameScreenshots\\LastWar",
  "MaxStorageGB": 5.0
}
```

---

### Logging

Full details in [Logging.md](Logging.md). Quick reference:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Logging.Backend` | string | `"EventLog"` | `File`, `EventLog`, or `File,EventLog` |
| `Logging.MinimumLogLevel` | string | `"Info"` | `Verbose`, `Info`, `Warning`, `Error` |
| `Logging.FileBackend.MaxSizeMB` | int | `10` | Max log file size before rollover (1-10240) |
| `Logging.FileBackend.MaxAgeDays` | int | `30` | Delete log files older than this (1-3650) |
| `Logging.FileBackend.MaxLogFileCount` | int | `500` | Max log files to keep; oldest deleted when reached (1-100000) |
