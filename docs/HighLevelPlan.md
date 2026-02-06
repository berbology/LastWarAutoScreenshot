# High-Level Task List for Auto Mouse Control Module

## Window Management & Safety

1. [ ] Enumerate all open windows, including minimized and background apps, and allow user to select a target (e.g., LastWar.exe)
   1. [ ] Design and create PowerShell Type Definitions for Win32 API window enumeration
      - [ ] Define P/Invoke signatures for `EnumWindows` callback
      - [ ] Define P/Invoke signatures for `GetWindowText` and `GetWindowTextLength`
      - [ ] Define P/Invoke signatures for `IsWindowVisible`
      - [ ] Define P/Invoke signatures for `GetWindowThreadProcessId`
      - [ ] Define P/Invoke signatures for `IsIconic` (check if minimized)
      - [ ] Create `WindowEnumeration_TypeDefinition.ps1` in `private/` folder
      - [ ] Add proper error handling for P/Invoke calls
   2. [ ] Implement window enumeration function
      - [ ] Create private function `Get-EnumeratedWindows` with comment-based help
      - [ ] Implement enumeration logic using Win32 API callbacks
      - [ ] Return collection of window objects with properties: ProcessName, WindowTitle, WindowHandle, PID, WindowState (Visible/Minimized)
      - [ ] Ensure function is modular and testable via Pester
   3. [ ] Implement window filtering logic
      - [ ] Filter out windows with empty or null titles
      - [ ] Filter out system windows and background processes
      - [ ] Only include windows that would appear in main taskbar area
      - [ ] Log filtered window count in verbose mode
   4. [ ] Implement console-based menu for user selection
      - [ ] Create private function `Select-TargetWindowFromMenu` with comment-based help
      - [ ] Display numbered list showing ProcessName, WindowTitle, WindowState
      - [ ] Accept user input (number) for window selection
      - [ ] Validate user input and handle invalid selections
      - [ ] Allow user to cancel selection (e.g., 'q' or '0')
      - [ ] Keep code modular for future GUI integration
   5. [ ] Implement configuration persistence
      - [ ] Check if existing configuration file exists
      - [ ] Prompt user to save current config before overwriting (if exists)
      - [ ] Create function to save selected window target to configuration
      - [ ] Store ProcessName, WindowTitle, WindowHandle in config
   6. [ ] Implement error handling for all scenarios
      - [ ] Handle case: no windows found after filtering (log error, quit gracefully)
      - [ ] Handle case: user cancels selection (log info, close gracefully with message)
      - [ ] Handle case: selected window closes before action starts (log error, show error popup)
      - [ ] Add try-catch blocks around all Win32 API calls
   7. [ ] Add Windows Event Logging
      - [ ] Log verbose details: PID, WindowHandle, WindowState, ProcessName, WindowTitle
      - [ ] Log info: user selection, filtered window count
      - [ ] Log errors: no windows found, invalid selection, window closed
      - [ ] Log warnings: config file overwrite prompts
   8. [ ] Create Pester unit tests
      - [ ] Create `WindowEnumeration.Tests.ps1` in appropriate test folder
      - [ ] Mock Win32 API calls for enumeration function tests
      - [ ] Test filtering logic with various window states
      - [ ] Test console menu input validation (valid, invalid, cancel)
      - [ ] Test configuration save/load logic
      - [ ] Test error handling scenarios
      - [ ] Achieve minimum 80% code coverage
   9. [ ] Update README.md
      - [ ] Document new exported functions (if any made public)
      - [ ] Update "Features" section to reflect window enumeration capabilities
      - [ ] Add usage examples for window selection workflow
      - [ ] Document configuration schema for window target settings
2. [ ] Implement window state management: bring target window to front, restore if minimized, detect and handle window close/crash events
3. [ ] Implement emergency stop mechanisms:
   - Configurable hotkey combination (default: Ctrl+Shift+Esc)
   - Mouse gesture: hold both mouse buttons simultaneously for 3 seconds
   - Log all emergency stop events

## Mouse Control & Interaction

4. [ ] Implement mouse movement and click logic using Windows API or System.Windows.Forms with window-relative coordinate system
2. [ ] Develop human-like mouse movement with:
   - Randomized delays and variable timing to mimic human behavior
   - Curved paths (not straight lines) to avoid bot detection
   - Configurable speed ranges and randomness factors
   - Variable duration between mouse-up and mouse-down events
3. [ ] Allow user to define bounding box or circle as cursor target; randomly select position within defined area for each action

## GUI & Recording

7. [ ] Design and implement GUI for:
   - Interactive recording of mouse actions (move, click, drag)
   - Visual selection of screenshot regions
   - Configuration of emergency stop hotkeys
   - Display of local storage usage (GB) with progress bar
   - "Logging" tab for verbosity configuration
   - Retry logic configuration for failures
2. [ ] Implement action recording that generates user settings files (not JSON by default, but JSON import/export supported)
3. [ ] Enable manual editing, saving, and importing of configuration files

## Configuration & Scheduling

10. [ ] Design and implement configuration schema supporting both JSON and YAML formats:

- Window target settings
- Action sequences with window-relative coordinates
- Human-like interaction parameters
- Emergency stop configuration
- Storage limits and screenshot settings
- Logging preferences
- Azure upload settings (for future use)

11. [ ] Integrate with Windows Task Scheduler for automated execution:

- Start date/time configuration
- Repeat interval settings (e.g., every 6 hours)
- Repeat duration (fixed or indefinite)
- Random delay before task start (0-120 minutes)
- Task expiration and stop conditions
- Reference Windows Task Scheduler "Edit Trigger" dialog for UI patterns

## Screenshot Management

12. [ ] Add screenshot functionality for user-defined screen regions:

- Support PNG and JPEG formats
- Configurable filename patterns (timestamp, index placeholders)
- Window-relative region coordinates

13. [ ] Implement screenshot similarity detection using pixel-based comparison:

- Algorithm: Pixel-by-pixel comparison with tolerance threshold
- Default threshold: >98% pixel match indicates identical screenshots
- Used to detect end of scrolling lists without OCR
- Threshold configurable by user

14. [ ] Implement local storage management:

- Default limit: 2GB for screenshot storage
- User-configurable maximum limit
- GUI progress indicator showing usage in GB
- Prompt user when limit reached with actionable suggestions (increase limit or cleanup)
- Prompt user when drive is full

## Error Handling & Logging

15. [ ] Implement Windows Event Logging for all errors and diagnostics:

- Verbose mode during development (log everything)
- Debug mode: include all relevant variables in error events
- Configurable verbosity via command-line or GUI
- Specific logging levels to be defined as features develop

16. [ ] Implement error recovery and retry logic:

- Mid-sequence failures: log error event with full context, configurable retry
- Window close/crash detection: abort sequence gracefully, log event
- Exponential backoff with jitter for retry attempts
- User-configurable retry settings in GUI

## Module Installation & Versioning

17. [ ] Implement PowerShell v7 best practices for module installation:

- Support installation to user and system module paths
- Proper module manifest (psd1) with metadata
- Exported functions defined in manifest (as developed)
- Semantic versioning for module releases

18. [ ] Create installation documentation and example commands

## Azure Integration (Future)

19. [ ] Prepare for future Azure Blob upload integration:

- Design extensible screenshot saving logic
- SAS token-based authentication
- Exponential backoff with jitter for upload retry logic
- Configurable retry attempts
- Upload failure handling with same retry logic as other operations

## Documentation & Examples

20. [ ] Create example configuration files with inline comments
2. [ ] Document window-relative coordinate system
3. [ ] Provide quick start guide with simple working example
4. [ ] Document all exported PowerShell functions as they are created
