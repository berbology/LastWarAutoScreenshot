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
