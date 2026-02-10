# LastWar Auto Mouse Control & Screenshot Module

## Overview

This project is a PowerShell 7+ module designed to automate human-like mouse movements, clicks, drags, and screen captures within Windows applications—primarily targeting the game Last War: Survival (`LastWar.exe`). The module uses window-relative coordinates for reliable automation across different display configurations and is extensible for other games or applications.

**Note:** This module is designed for Windows 11 (64-bit) where the target game is supported. Only one instance can run at a time since the game supports single-instance execution only.

## Features

- **Window Management:** Enumerate all open windows (including minimized/background), select target window, automatically bring to front and restore if minimized
  - Uses Win32 API (`EnumWindows`, `GetWindowText`, `IsWindowVisible`, `IsIconic`) via P/Invoke for reliable window enumeration
  - Proper memory management with delegate lifetime handling to prevent garbage collection issues
- **Emergency Stop:** Configurable hotkey combination (default: Ctrl+Shift+Esc) or hold both mouse buttons for 3 seconds to immediately abort automation
- **Window-Relative Coordinates:** All mouse positions are relative to the target window for consistency across different screen configurations
- **Human-Like Interaction:** Configurable mouse movement with randomized delays, curved paths, and variable timing to mimic human behavior and avoid detection as automated input
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

## Error Handling & Logging

### Logging

All error and diagnostic logging is performed via Windows Event Logging, viewable in Windows Event Viewer. During development, the module runs in Verbose mode with high verbosity, logging all operations for troubleshooting.

**Logging Configuration:**

- Verbosity level configurable via command-line parameters or GUI "Logging" tab
- Debug mode includes all relevant variables in error log events
- Specific logging levels and events will be documented as features are developed

### Error Recovery

- **Mid-Sequence Failures:** All failures are logged with full context; configurable retry logic available via GUI
- **Window Crashes/Closes:** Detected and logged; sequence aborts gracefully with error event
- **Upload Failures:** Exponential backoff with jitter for retry attempts (configurable max attempts)
- **Storage Limits:** User prompted with actionable suggestions (increase limit or cleanup drive)

### Emergency Stop

- **Hotkey:** Press configurable key combination (default: Ctrl+Shift+Esc) to immediately abort
- **Mouse Gesture:** Hold both mouse buttons simultaneously for 3 seconds to trigger emergency stop
- All emergency stops are logged for audit purposes

## Configuration

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
