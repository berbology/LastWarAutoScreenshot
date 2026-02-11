# High-Level Task List for Auto Mouse Control Module

## Window Management & Safety

1. [ ] Enumerate all open windows, including minimized and background apps, and allow user to select a target (e.g., LastWar.exe)
   1. [x] Design and create PowerShell Type Definitions for Win32 API window enumeration
      - [x] Define P/Invoke signatures for `EnumWindows` callback
      - [x] Define P/Invoke signatures for `GetWindowText` and `GetWindowTextLength`
      - [x] Define P/Invoke signatures for `IsWindowVisible`
      - [x] Define P/Invoke signatures for `GetWindowThreadProcessId`
      - [x] Define P/Invoke signatures for `IsIconic` (check if minimized)
      - [x] Define P/Invoke signatures for `GetForegroundWindow` (detect active window)
      - [x] Create `WindowEnumeration_TypeDefinition.ps1` in `private/` folder
      - [x] Add proper error handling for P/Invoke calls
   2. [x] Implement window enumeration function
      - [x] Create private function `Get-EnumeratedWindows` with comment-based help
      - [x] Implement enumeration logic using Win32 API callbacks
      - [x] Return collection of window objects with properties: ProcessName, WindowTitle, WindowHandle, PID, WindowState (Visible/Minimized)
      - [x] Ensure function is modular and testable via Pester
      - [x] Add optional filtering parameters: -ProcessName, -ExcludeMinimized, -VisibleOnly
      - [x] Implement ForEach-Object -Parallel optimization for Get-Process calls (ThrottleLimit 16)
      - [x] Handle process termination between enumeration and Get-Process gracefully
      - [x] Return both raw IntPtr handle and serializable string/int64 formats
      - [x] Filter out empty/null window titles and hidden system processes
      - [x] Collect enumeration errors for Event Log reporting
      - [x] Add comprehensive verbose output at each processing stage
      - [x] Create Pester unit tests with mock helper function New-MockWindowData
   3. [x] Implement console-based menu for user selection
      - [x] Create private function `Select-TargetWindowFromMenu` with comment-based help
      - [x] Display numbered list showing Process, Application (WindowTitle), Minimised status, Active indicator
      - [x] Accept user input (number) for window selection
      - [x] Validate user input and handle invalid selections
      - [x] Allow user to cancel selection (press 'x' to exit)
      - [x] Keep code modular for future GUI integration
      - [x] Implement arrow key navigation with scroll mode and blue text highlighting
      - [x] Support sorting by Process (P), Application (A), or Minimised (M) with ascending/descending toggle
      - [x] Implement simple and detailed view modes (toggle with D key)
      - [x] Add refresh capability (R key) for internally enumerated windows
      - [x] Display help menu (H key) below window list
      - [x] Detect and mark active (foreground) window with asterisk
      - [x] Use ANSI escape codes for colors and underlined header text
      - [x] Create comprehensive Pester unit tests in `Select-TargetWindowFromMenu.Tests.ps1`
   4. [ ] Implement configuration persistence
      - [ ] Check if existing configuration file exists
      - [ ] Prompt user to save current config before overwriting (if exists)
      - [ ] Create function to save selected window target to configuration
      - [ ] Store ProcessName, WindowTitle, WindowHandle in config
   5. [ ] Implement error handling for all scenarios
      - [ ] Handle case: no windows found after filtering (log error, quit gracefully)
      - [ ] Handle case: user cancels selection (log info, close gracefully with message)
      - [ ] Handle case: selected window closes before action starts (log error, show error popup)
      - [ ] Add try-catch blocks around all Win32 API calls
   6. [ ] Add Windows Event Logging
      - [ ] Log verbose details: PID, WindowHandle, WindowState, ProcessName, WindowTitle
      - [ ] Log info: user selection, filtered window count
      - [ ] Log errors: no windows found, invalid selection, window closed
      - [ ] Log warnings: config file overwrite prompts
   7. [ ] Create Pester unit tests
      - [ ] Create `WindowEnumeration.Tests.ps1` in appropriate test folder
      - [ ] Mock Win32 API calls for enumeration function tests
      - [ ] Test filtering logic with various window states
      - [ ] Test console menu input validation (valid, invalid, cancel)
      - [ ] Test configuration save/load logic
      - [ ] Test error handling scenarios
      - [ ] Achieve minimum 80% code coverage
   8. [ ] Update README.md
      - [ ] Document new exported functions (if any made public)
      - [ ] Update "Features" section to reflect window enumeration capabilities
      - [ ] Add usage examples for window selection workflow
      - [ ] Document configuration schema for window target settings
2. [ ] Implement window state management: bring target window to front, restore if minimized, detect and handle window close/crash events
   1. [ ] Extend PowerShell Type Definitions for window state management
      - [ ] Add P/Invoke signature for `ShowWindow` (restore/minimize window)
      - [ ] Add P/Invoke signature for `SetForegroundWindow` (bring window to front)
      - [ ] Update `WindowEnumeration_TypeDefinition.ps1` accordingly
3. [ ] Implement emergency stop mechanisms:
   - Configurable hotkey combination (default: Ctrl+Shift+Esc)
   - Mouse gesture: hold both mouse buttons simultaneously for 3 seconds
   - Log all emergency stop events

## Mouse Control & Interaction

1. [ ] Implement mouse movement and click logic using Windows API or System.Windows.Forms with window-relative coordinate system
2. [ ] Develop human-like mouse movement with:
   - Randomized delays and variable timing to mimic human behaviour
   - Curved paths (not straight lines) to avoid bot detection
   - Configurable speed ranges and randomness factors
   - Variable duration between mouse-up and mouse-down events
3. [ ] Allow user to define bounding box or circle as cursor target; randomly select position within defined area for each action

## GUI & Recording

1. [ ] Design and implement GUI for:
   - Interactive recording of mouse actions (move, click, drag)
   - Visual selection of screenshot regions
   - Configuration of emergency stop hotkeys
   - Display of local storage usage (GB) with progress bar
   - "Logging" tab for verbosity configuration
   - Retry logic configuration for failures
2. [ ] Implement action recording that generates user settings files (not JSON by default, but JSON import/export supported)
3. [ ] Enable manual editing, saving, and importing of configuration files

## Configuration & Scheduling

1. [ ] Design and implement configuration schema supporting both JSON and YAML formats:

- Window target settings
- Action sequences with window-relative coordinates
- Human-like interaction parameters
- Emergency stop configuration
- Storage limits and screenshot settings
- Logging preferences
- Azure upload settings (for future use)

1. [ ] Integrate with Windows Task Scheduler for automated execution:

- Start date/time configuration
- Repeat interval settings (e.g., every 6 hours)
- Repeat duration (fixed or indefinite)
- Random delay before task start (0-120 minutes)
- Task expiration and stop conditions
- Reference Windows Task Scheduler "Edit Trigger" dialog for UI patterns

## Screenshot Management

1. [ ] Add screenshot functionality for user-defined screen regions:

- Support PNG and JPEG formats
- Configurable filename patterns (timestamp, index placeholders)
- Window-relative region coordinates

1. [ ] Implement screenshot similarity detection using pixel-based comparison:

- Algorithm: Pixel-by-pixel comparison with tolerance threshold
- Default threshold: >98% pixel match indicates identical screenshots
- Used to detect end of scrolling lists without OCR
- Threshold configurable by user

1. [ ] Implement local storage management:

- Default limit: 2GB for screenshot storage
- User-configurable maximum limit
- GUI progress indicator showing usage in GB
- Prompt user when limit reached with actionable suggestions (increase limit or cleanup)
- Prompt user when drive is full

## Error Handling & Logging

1. [ ] Implement Windows Event Logging for all errors and diagnostics:

- Verbose mode during development (log everything)
- Debug mode: include all relevant variables in error events
- Configurable verbosity via command-line or GUI
- Specific logging levels to be defined as features develop

1. [ ] Implement error recovery and retry logic:

- Mid-sequence failures: log error event with full context, configurable retry
- Window close/crash detection: abort sequence gracefully, log event
- Exponential backoff with jitter for retry attempts
- User-configurable retry settings in GUI

## Module Installation & Versioning

1. [ ] Implement PowerShell v7 best practices for module installation:

- Support installation to user and system module paths
- Proper module manifest (psd1) with metadata
- Exported functions defined in manifest (as developed)
- Semantic versioning for module releases

1. [ ] Create installation documentation and example commands

## Azure Integration (Future)

1. [ ] Prepare for future Azure Blob upload integration:

- Design extensible screenshot saving logic
- SAS token-based authentication
- Exponential backoff with jitter for upload retry logic
- Configurable retry attempts
- Upload failure handling with same retry logic as other operations

## Documentation & Examples

1. [ ] Create example configuration files with inline comments
2. [ ] Document window-relative coordinate system
3. [ ] Provide quick start guide with simple working example
4. [ ] Document all exported PowerShell functions as they are created
