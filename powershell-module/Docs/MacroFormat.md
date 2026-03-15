## Macro Format Reference

This document describes the JSON macro file format used by
Last War AutoScript. Macros are created and edited through the interactive
console app; you do not need to edit the JSON directly. This reference is
provided for advanced users and contributors.

---

## File location and naming

Macro files are stored in the `Private/Macros/` folder inside the module root.

**Filename format:** `yyyyMMdd_HHmmss_<name>.json`

- The datetime prefix is the UTC creation timestamp.
- `<name>` is the macro name, containing only `[a-zA-Z0-9_-]` (max 50 chars).
- The prefix is preserved when you rename a macro through the "Manage macros"
  screen — only the `<name>` portion changes.

**Example:** `20260310_143022_GetVsScores.json`

---

## Top-level structure

```json
{
    "version": "1.0",
    "metadata": { ... },
    "targetWindow": { ... },
    "sequence": [ ... ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version. Must be `"1.0"`. |
| `metadata` | object | Yes | Descriptive information about the macro. |
| `targetWindow` | object | Yes | Process and window title the macro was recorded for. |
| `sequence` | array | Yes | Ordered list of action objects. Must contain at least one action. |

---

## `metadata` object

```json
"metadata": {
    "name": "get-vs-scores",
    "createdUtc": "2026-02-24T12:12:12Z",
    "modifiedUtc": "2026-02-24T12:12:12Z",
    "description": ""
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Macro name. Same character rules as filename (`[a-zA-Z0-9_-]`, 1–50 chars). |
| `createdUtc` | string | Yes | ISO 8601 UTC timestamp when the macro was first saved. |
| `modifiedUtc` | string | Yes | ISO 8601 UTC timestamp when the macro was last saved. |
| `description` | string | No | Free-text description. May be empty string. |

---

## `targetWindow` object

```json
"targetWindow": {
    "processName": "LastWar",
    "windowTitle": "Last War: Survival"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `processName` | string | Yes | Process name of the target application (no `.exe` suffix). |
| `windowTitle` | string | Yes | Window title of the target application. |

At run time, if the current configured window's `processName` differs from
this value a warning is shown before execution.

---

## `sequence` array

An ordered array of action objects. Actions execute in index order.
`Loop` actions can repeat a set of named actions N times; the loop walks
the sequence in the order defined by its `actionNames` array.

### Common fields (all action types)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Action type identifier. See the table below. |
| `name` | string | No | Optional unique name for this action within the macro. Used by `Loop`. Must match `[a-zA-Z0-9_-]` (1–50 chars). Names are unique case-insensitively across the entire sequence. |

---

## Action type reference

### `MoveToPoint`

Move the mouse to an exact window-relative position.

```json
{
    "name": "target-vs-icon",
    "type": "MoveToPoint",
    "position": {
        "relativeX": 0.452,
        "relativeY": 0.621
    }
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `position.relativeX` | double | 0.0–1.0 | Horizontal position relative to window width. 0.0 = left edge, 1.0 = right edge. |
| `position.relativeY` | double | 0.0–1.0 | Vertical position relative to window height. 0.0 = top edge, 1.0 = bottom edge. |

---

### `MoveToRegion`

Move to a random point within a region (box or circle). The random point is
chosen at execution time using `Get-RandomTargetPosition`.

#### Box sub-type

```json
{
    "name": "ranking-icon",
    "type": "MoveToRegion",
    "region": {
        "type": "Box",
        "relativeX": 0.30,
        "relativeY": 0.20,
        "relativeWidth": 0.10,
        "relativeHeight": 0.05
    }
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `region.type` | string | `"Box"` | Sub-type identifier. |
| `region.relativeX` | double | 0.0–1.0 | Left edge of the box. |
| `region.relativeY` | double | 0.0–1.0 | Top edge of the box. |
| `region.relativeWidth` | double | 0.0–1.0 | Width of the box as a fraction of window width. |
| `region.relativeHeight` | double | 0.0–1.0 | Height of the box as a fraction of window height. |

#### Circle sub-type

```json
{
    "name": "target-vs-icon",
    "type": "MoveToRegion",
    "region": {
        "type": "Circle",
        "relativeCentreX": 0.452,
        "relativeCentreY": 0.621,
        "relativeRadius": 0.053
    }
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `region.type` | string | `"Circle"` | Sub-type identifier. |
| `region.relativeCentreX` | double | 0.0–1.0 | Centre X position. |
| `region.relativeCentreY` | double | 0.0–1.0 | Centre Y position. |
| `region.relativeRadius` | double | 0.0–1.0 | Radius as a fraction of window width. |

Random point distribution is uniform over the area (the radius is square-rooted
before applying polar coordinates so points are not concentrated at the centre).

---

### `LeftClick`

Click at the current cursor position. No coordinate properties are required.
Typically follows a `MoveToPoint` or `MoveToRegion` action.

```json
{
    "type": "LeftClick"
}
```

```json
{
    "name": "confirm-button",
    "type": "LeftClick"
}
```

---

### `DragClick`

Hold the left mouse button at the start position, move via a Bezier path to
the end position, then release. Used for scroll gestures.

```json
{
    "name": "scroll-next-vs-scores",
    "type": "DragClick",
    "start": { "relativeX": 0.50, "relativeY": 0.80 },
    "end":   { "relativeX": 0.50, "relativeY": 0.20 }
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `start.relativeX` | double | 0.0–1.0 | Horizontal start position. |
| `start.relativeY` | double | 0.0–1.0 | Vertical start position. |
| `end.relativeX` | double | 0.0–1.0 | Horizontal end position (button released here). |
| `end.relativeY` | double | 0.0–1.0 | Vertical end position (button released here). |

The mouse button is released in a `finally` block to ensure it is always
freed, even if an emergency stop fires mid-drag.

---

### `Screenshot`

Captures a screenshot of a specified region of the target window and saves it
to the configured `Screenshots.StoragePath`. Requires `Screenshots.StoragePath`
to be configured; if unconfigured the action is skipped with a `Warning` log
during execution (non-fatal — the macro continues normally).

```json
{
    "name": "vs-score-screenshot-region",
    "type": "Screenshot",
    "region": {
        "topLeft":     { "relativeX": 0.10, "relativeY": 0.15 },
        "bottomRight": { "relativeX": 0.90, "relativeY": 0.85 }
    },
    "maskRegions": [
        {
            "topLeft":     { "relativeX": 0.30, "relativeY": 0.40 },
            "bottomRight": { "relativeX": 0.55, "relativeY": 0.50 }
        }
    ]
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `region.topLeft.relativeX` | double | 0.0–1.0 | Left edge of the capture region. |
| `region.topLeft.relativeY` | double | 0.0–1.0 | Top edge of the capture region. |
| `region.bottomRight.relativeX` | double | 0.0–1.0 | Right edge. Must be greater than `topLeft.relativeX`. |
| `region.bottomRight.relativeY` | double | 0.0–1.0 | Bottom edge. Must be greater than `topLeft.relativeY`. |
| `maskRegions` | array | optional, max 10 | Regions filled with the configured mask colour before the file is saved. Same window-relative coordinate space as `region`. Omit or use `[]` for no masking. |
| `maskRegions[i].topLeft.relativeX` | double | 0.0–1.0 | Left edge of the mask region. |
| `maskRegions[i].topLeft.relativeY` | double | 0.0–1.0 | Top edge of the mask region. |
| `maskRegions[i].bottomRight.relativeX` | double | 0.0–1.0 | Right edge of the mask region. Must be greater than `topLeft.relativeX`. |
| `maskRegions[i].bottomRight.relativeY` | double | 0.0–1.0 | Bottom edge of the mask region. Must be greater than `topLeft.relativeY`. |

The fill colour for all mask regions is controlled by `Screenshots.MaskColour` in module
configuration (default: `"0,0,0"` — pure black). Mask regions that do not overlap the
screenshot `region` have no visible effect but are not a validation error.

Naming screenshot actions is recommended when they will be referenced by loops.

#### Screenshot Capture Behaviour

`region.topLeft` and `region.bottomRight` are window-relative coordinates
(0.0–1.0 on each axis). The capture region is computed at execution time using
the live window bounds — the window must be open, visible, and in windowed or
borderless-windowed mode (not minimised, not exclusive fullscreen).

The full window is never captured — only the rectangle defined by `topLeft`
and `bottomRight` is written to disk. Capture uses `PrintWindow` with the
`PW_RENDERFULLCONTENT` flag so that OpenGL-rendered content (composited via
DWM) is captured correctly.

Files are saved as PNG (lossless) and named according to
`Screenshots.FilenamePattern`. Configure storage in the app under
**Configure module → Screenshot settings**.

---

### `Delay`

Pause execution for a fixed duration.

```json
{
    "type": "Delay",
    "seconds": 5
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `seconds` | double | 0.1–3600 | How long to wait. |

---

### `Loop`

Repeat a set of named actions N times.

```json
{
    "name": "loop-get-vs-screenshots",
    "type": "Loop",
    "iterations": 19,
    "actionNames": [
        "move-vs-score-bottom",
        "scroll-next-vs-scores",
        "vs-score-screenshot-region"
    ]
}
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `iterations` | int | 1–10 000 | How many times to repeat the action set. |
| `actionNames` | string[] | Non-empty | Names of the actions to repeat, in execution order. Each name must resolve to a named action in the same sequence. An action name can appear more than once. |

**Constraints:**

- `actionNames` must reference actions that exist and are named in the
  `sequence` array.
- `Loop` actions cannot reference other `Loop` actions (no nesting).
- These constraints are validated at save time and reported as errors if
  violated.

---

## Validation rules summary

| Rule | Error message |
|------|---------------|
| `version` missing or not `"1.0"` | `"Invalid or missing 'version' field"` |
| `metadata.name` invalid | Message from `Get-ValidMacroName` |
| `metadata.createdUtc` not ISO 8601 | `"'createdUtc' is not a valid ISO 8601 date"` |
| `targetWindow.processName` empty | `"'targetWindow.processName' must not be empty"` |
| `sequence` empty | `"'sequence' must contain at least one action"` |
| Duplicate action `name` | `"Duplicate action name: '<name>'"` |
| Unknown action `type` | `"Unknown action type: '<type>'"` |
| Required property missing | `"'<property>' is required for <type> actions"` |
| Numeric property out of range | `"'<property>' must be between <min> and <max>"` |
| `Screenshot` bottom-right not below/right of top-left | `"bottomRight must be below and to the right of topLeft"` |
| `Screenshot.maskRegions` length exceeds 10 | `"Screenshot action '<name>': maskRegions must contain at most 10 entries"` |
| `Screenshot.maskRegions[i].bottomRight.relativeX` ≤ `topLeft.relativeX` | `"Screenshot action '<name>': maskRegions[i].bottomRight.relativeX must be greater than topLeft.relativeX"` |
| `Screenshot.maskRegions[i].bottomRight.relativeY` ≤ `topLeft.relativeY` | `"Screenshot action '<name>': maskRegions[i].bottomRight.relativeY must be greater than topLeft.relativeY"` |
| `Loop.actionNames` references non-existent name | `"Loop references unknown action: '<name>'"` |
| `Loop.actionNames` references a `Loop` action | `"Loop cannot reference another Loop action: '<name>'"` |
| `Loop.actionNames` empty | `"'actionNames' must contain at least one entry"` |
| `Loop.iterations` zero | `"'iterations' must be between 1 and 10000"` |

All validation errors are returned as an array by `Test-MacroFile`; the "Save
macro" screen displays them all before allowing further editing.

---

## Example macros

### Example 1 — Get VS Scores

Records the full workflow for capturing VS (Victory Stage) score screenshots:
open the VS screen, navigate to rankings, take a screenshot, scroll down,
repeat.

```json
{
    "version": "1.0",
    "metadata": {
        "name": "get-vs-scores",
        "createdUtc": "2026-02-24T12:12:12Z",
        "modifiedUtc": "2026-02-24T12:12:12Z",
        "description": "Capture all VS score pages for OCR processing"
    },
    "targetWindow": {
        "processName": "LastWar",
        "windowTitle": "Last War: Survival"
    },
    "sequence": [
        {
            "name": "target-vs-icon",
            "type": "MoveToRegion",
            "region": {
                "type": "Circle",
                "relativeCentreX": 0.452,
                "relativeCentreY": 0.621,
                "relativeRadius": 0.053
            }
        },
        { "type": "LeftClick" },
        {
            "name": "ranking-icon",
            "type": "MoveToRegion",
            "region": {
                "type": "Box",
                "relativeX": 0.30,
                "relativeY": 0.20,
                "relativeWidth": 0.10,
                "relativeHeight": 0.05
            }
        },
        { "type": "LeftClick" },
        {
            "name": "vs-score-screenshot-region",
            "type": "Screenshot",
            "region": {
                "topLeft":     { "relativeX": 0.10, "relativeY": 0.15 },
                "bottomRight": { "relativeX": 0.90, "relativeY": 0.85 }
            }
        },
        {
            "name": "move-vs-score-bottom",
            "type": "MoveToPoint",
            "position": { "relativeX": 0.50, "relativeY": 0.90 }
        },
        {
            "name": "scroll-next-vs-scores",
            "type": "DragClick",
            "start": { "relativeX": 0.50, "relativeY": 0.80 },
            "end":   { "relativeX": 0.50, "relativeY": 0.20 }
        },
        {
            "name": "loop-get-vs-screenshots",
            "type": "Loop",
            "iterations": 19,
            "actionNames": [
                "move-vs-score-bottom",
                "scroll-next-vs-scores",
                "vs-score-screenshot-region"
            ]
        },
        {
            "type": "MoveToPoint",
            "position": { "relativeX": 0.05, "relativeY": 0.05 }
        },
        { "type": "LeftClick" },
        { "type": "Delay", "seconds": 5 },
        { "type": "LeftClick" },
        { "type": "Delay", "seconds": 5 },
        { "type": "LeftClick" }
    ]
}
```

**Sequence walkthrough:**

1. Move to VS icon (circle region) and click — opens the VS score screen.
2. Move to rankings icon (box region) and click — opens rankings view.
3. Screenshot the score table and save to the configured storage path.
4. Move to bottom of the list and drag-scroll up to load the next page.
5. **Loop × 19** — repeat scroll and screenshot for the remaining pages.
6. Three clicks separated by 5-second delays to dismiss menus.

---

### Example 2 — Get Arms Race Scores

Records the workflow for capturing Arms Race score screenshots.

```json
{
    "version": "1.0",
    "metadata": {
        "name": "get-arms-race-scores",
        "createdUtc": "2026-02-24T12:12:12Z",
        "modifiedUtc": "2026-02-24T12:12:12Z",
        "description": "Capture Arms Race score pages for OCR processing"
    },
    "targetWindow": {
        "processName": "LastWar",
        "windowTitle": "Last War: Survival"
    },
    "sequence": [
        {
            "name": "target-events-icon",
            "type": "MoveToRegion",
            "region": {
                "type": "Circle",
                "relativeCentreX": 0.12,
                "relativeCentreY": 0.88,
                "relativeRadius": 0.04
            }
        },
        { "type": "LeftClick" },
        {
            "name": "move-arms-race-score-bottom",
            "type": "MoveToPoint",
            "position": { "relativeX": 0.50, "relativeY": 0.90 }
        },
        {
            "name": "scroll-next-arms-race-scores",
            "type": "DragClick",
            "start": { "relativeX": 0.50, "relativeY": 0.80 },
            "end":   { "relativeX": 0.50, "relativeY": 0.20 }
        },
        {
            "name": "arms-race-screenshot-region",
            "type": "Screenshot",
            "region": {
                "topLeft":     { "relativeX": 0.05, "relativeY": 0.10 },
                "bottomRight": { "relativeX": 0.95, "relativeY": 0.90 }
            }
        },
        { "type": "LeftClick" },
        { "type": "Delay", "seconds": 5 },
        { "type": "LeftClick" },
        { "type": "Delay", "seconds": 5 },
        { "type": "LeftClick" }
    ]
}
```

**Sequence walkthrough:**

1. Move to the events icon (circle region) and click.
2. Move to the bottom of the Arms Race list.
3. Drag-scroll up to reveal scores.
4. Screenshot the score table and save to the configured storage path.
5. Three clicks with 5-second delays to dismiss menus.

---

## See also

- [README.md](README.md) — full user guide including macro recording
  walkthrough and managing macros
- [ConsoleApp.md](ConsoleApp.md) — console app screen map and `IAnsiConsole`
  injection pattern for contributors
- [Configuration.md](Configuration.md) — all `MouseControl`, `EmergencyStop`,
  and `Logging` config keys
