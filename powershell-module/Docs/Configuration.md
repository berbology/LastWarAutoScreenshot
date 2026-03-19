## Configuration Reference

All settings live in `$env:APPDATA\LastWarAutoScreenshot\ModuleConfig.json`.
The file is created automatically with defaults on first run - you generally
won't need to edit it by hand; use `Start-LWASConsole` → Configure
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

### Scheduled task launcher scripts

When you register a scheduled macro task, the module automatically generates a launcher PowerShell script at:

```
$env:APPDATA\LastWarAutoScreenshot\Schedulers\LWAS_<MacroName>.ps1
```

This directory and its contents are managed automatically by the module — do not edit or delete launcher scripts manually. Launcher scripts are deleted automatically when their corresponding task is unregistered via `Unregister-LWASScheduledTask`.

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
| `MinMovementDurationMs` | int | `200` | Minimum total move time (ms) |
| `MaxMovementDurationMs` | int | `600` | Maximum total move time (ms) |
| `ClickDownDurationRangeMs` | int[] | `[50, 150]` | Mouse-down hold time range (ms) |
| `ClickPreDelayRangeMs` | int[] | `[50, 200]` | Delay before click (ms) |
| `MinClickPostDelayMs` | int | `100` | Minimum delay after click (ms) |
| `MaxClickPostDelayMs` | int | `300` | Maximum delay after click (ms) |
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
  "MinMovementDurationMs": 200,
  "MaxMovementDurationMs": 600,
  "ClickDownDurationRangeMs": [50, 150],
  "PathPointCount": 20
}
```

#### Cursor target regions

`MoveToRegion` macro actions land at a random point inside a defined area
rather than a fixed coordinate. Regions are specified in the macro JSON using
window-relative values in `[0.0, 1.0]`.

**Box** (uniform random within rectangle):

```json
{
  "type": "MoveToRegion",
  "region": {
    "type": "Box",
    "relativeX": 0.2,
    "relativeY": 0.3,
    "relativeWidth": 0.4,
    "relativeHeight": 0.2
  }
}
```

**Circle** (uniform random within disc):

```json
{
  "type": "MoveToRegion",
  "region": {
    "type": "Circle",
    "relativeCentreX": 0.5,
    "relativeCentreY": 0.5,
    "relativeRadius": 0.15
  }
}
```

All values must be in `[0.0, 1.0]`; out-of-range input logs an error and
the action is skipped.

---

### EmergencyStop

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `AutoStart` | bool | `true` | Start monitor automatically with `Invoke-MacroSequence` |
| `HotkeyKeyNames` | string | `"Ctrl+Alt+Q"` | Key combination string; converted to virtual key codes at runtime |
| `PollIntervalMs` | int | `100` | Polling frequency in ms (10-5000) |

The `#` key is only available as a standalone key on UK layouts. On other layouts
adjust `HotkeyKeyNames` to a combination available on your keyboard (e.g. `"Ctrl+Shift+P"`). See
[WindowManagement.md](WindowManagement.md) for full emergency stop details.

---

### Screenshots

Configured via **Configure module → Screenshot settings** in the app.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `StoragePath` | string | `""` | Folder where screenshots are saved. Empty = not configured |
| `MaxStorageGB` | double | `2.0` | Storage cap in GB (0.1–2048) |
| `StorageWarningThresholdPercent` | int | `90` | Warn when usage exceeds this percentage of `MaxStorageGB` (1–99) |
| `FileFormat` | string | `"PNG"` | File format for captured screenshots. Only `"PNG"` is supported |
| `FilenamePattern` | string | `"{MacroName}_{ActionName}_{Timestamp}_{Index}"` | Pattern for screenshot filenames. Supported placeholders: `{MacroName}`, `{ActionName}`, `{Timestamp}`, `{Date}`, `{Time}`, `{Index}` |
| `MaskColour` | string | `"0,0,0"` | Colour used to fill screenshot mask regions. Accepted formats: named colour (e.g. `"red"`, `"dark blue"`, `"light green"`), RGB triplet (e.g. `"255,0,0"`), or 6-character hex code (e.g. `"FF0000"`). Default is pure black. |

When `StoragePath` is empty the storage info screen prompts you to configure
it. The app shows a usage chart and warns when usage reaches
`StorageWarningThresholdPercent` of the storage cap.

#### `SimilarityCheck` sub-object

Controls automatic duplicate-screenshot detection. When consecutive
screenshots match at or above `Threshold`, the configured `Action` fires.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `SimilarityCheck.Enabled` | bool | `false` | Enable or disable duplicate detection |
| `SimilarityCheck.Threshold` | double | `0.98` | Fraction of sampled pixels that must match (0.01–1.0). `0.98` = 98% |
| `SimilarityCheck.SampleCount` | int | `1000` | Pixels to sample per comparison (100–100 000). Ignored when `FullScan` is `true` |
| `SimilarityCheck.FullScan` | bool | `false` | Compare every pixel — more accurate but slower |
| `SimilarityCheck.TolerancePerChannel` | int | `10` | Maximum per-channel (R/G/B) difference counted as a match (0–255). `0` = exact |
| `SimilarityCheck.Action` | string | `"StopLoop"` | Action on detection: `StopLoop`, `StopMacro`, or `Warn` |
| `SimilarityCheck.ConsecutiveThreshold` | int | `1` | Consecutive similar screenshots required before the action fires (1–100) |

**Example (ModuleConfig.json excerpt):**

```json
"Screenshots": {
  "StoragePath": "C:\\GameScreenshots\\LastWar",
  "MaxStorageGB": 5.0,
  "StorageWarningThresholdPercent": 90,
  "FileFormat": "PNG",
  "FilenamePattern": "{MacroName}_{ActionName}_{Timestamp}_{Index}",
  "MaskColour": "0,0,0",
  "SimilarityCheck": {
    "Enabled": true,
    "Threshold": 0.98,
    "SampleCount": 1000,
    "FullScan": false,
    "TolerancePerChannel": 10,
    "Action": "StopLoop",
    "ConsecutiveThreshold": 1
  }
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
