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
   4. [x] Implement configuration persistence
      - [x] Check if existing configuration file exists (Test-ModuleConfigurationExists)
      - [x] Prompt user to save current config before overwriting (ShouldProcess with -Force parameter)
      - [x] Create function to save selected window target to configuration (Save-ModuleConfiguration)
      - [x] Store ProcessName, WindowTitle, WindowHandle, ProcessID, WindowState, and metadata in config
      - [x] Create function to load configuration from file (Get-ModuleConfiguration)
      - [x] Create comprehensive Pester unit tests in `ModuleConfiguration.Tests.ps1` (26 tests, all passing)
   5. [x] Implement error handling for all scenarios
        - [x] 1.5.1: No Windows Found After Filtering
           - [x] Add check after window enumeration and filtering for empty result.
           - [x] Log an error event (to file or event log).
           - [x] Display a clear, user-friendly message and exit gracefully.
           - [x] Write a Pester test for this scenario.
        - [x] 1.5.2: User Cancels Selection
           - [x] Detect user cancellation (e.g., 'x' key or cancel input).
           - [x] Log an informational event.
           - [x] Display a confirmation message and exit gracefully.
           - [x] Write a Pester test for this scenario.
        - [x] 1.5.3: Selected Window Closes Before Action
           - [x] Before performing any action on the selected window, check if the window still exists.
           - [x] If not, log an error event.
           - [x] Show an error popup or message to the user.
           - [x] Ensure the workflow aborts cleanly.
           - [x] Write a Pester test for this scenario.
        - [x] 1.5.4: Add Try-Catch to All Win32 API Calls
           - [x] Review all Win32 API calls in enumeration and selection logic.
           - [x] Wrap each call in a try-catch block.
           - [x] On exception, log error details (including exception message and stack trace).
           - [x] Display a user-friendly error message.
           - [x] Write a Pester test that simulates a Win32 API failure.
        - [ ] 1.5.5: General Error Logging Consistency
            - [x] 1.5.5.1: Define standard logging format
               - [x] Specify required fields (function name, error type, context, timestamp, etc.)
               - [x] Document the format and update logging helper functions
            - [x] 1.5.5.2: Audit all error paths
               - [x] Review all functions for error/exception paths
               - [x] Ensure each path logs using the standardized format
               - [x] Add/modify log statements as needed
               - [x] Create/Amend tests for error logging
            - [x] 1.5.5.3: User feedback consistency
               - [x] Ensure every error log is paired with clear user-facing feedback
               - [x] Standardize user messages for common error types
            - [x] 1.5.5.4: Update/refactor logging functions
               - [x] Refactor or create logging functions to enforce the standard
               - [x] Add unit tests for these helpers
            - [x] 1.5.5.5: Pester tests for logging
               - [x] Mock logging/event functions
               - [x] Write tests to verify correct log output for each error scenario
            - [x] 1.5.5.6: Documentation
               - [x] Document the logging standard and usage in the codebase
   6. [ ] Add Windows Event Logging
      1. [x] Design Logging Backend Abstraction
         - [x] 1.6.1.1: Define interface/contract for logging backends (event log, file, etc.)
         - [x] 1.6.1.2: Update logging helper functions to use backend abstraction
         - [x] 1.6.1.3: Add configuration option to select logging backend (event log, file, both)
         - [x] 1.6.1.4: Document backend selection in module configuration schema
         - [x] 1.6.1.5: Create unit tests for backend abstraction and configuration logic
      2. [x] Implement Windows Event Log Backend
         - [x] 1.6.2.1: Register custom event log source ("LastWarAutoScreenshot") if not present
         - [x] 1.6.2.2: Implement event log writing using Write-EventLog (with fallback/error handling)
         - [x] 1.6.2.3: Define event types and IDs for verbose, info, warning, error
         - [x] 1.6.2.4: Ensure all log fields (PID, WindowHandle, etc.) are included in event details
         - [x] 1.6.2.5: Add logic to handle permission errors (e.g., fallback to Application log or prompt user)
         - [x] 1.6.2.6: Create unit tests for event log backend, including source registration, event writing, error handling, and field coverage
      3. [ ] Implement Local File Logging Backend Enhancements
         - [ ] 1.6.3.1: Add log file rollover (by size, count, or age; configurable)
         - [ ] 1.6.3.2: Implement cleanup of old log files based on retention policy
         - [ ] 1.6.3.3: Ensure log format matches documented standard
         - [ ] 1.6.3.4: Create unit tests for file logging enhancements, including rollover, cleanup, and format validation
      4. [ ] Update Logging Calls Throughout Codebase
         - [ ] 1.6.4.1: Refactor all logging calls to use new abstraction
         - [ ] 1.6.4.2: Ensure all loggable events (verbose, info, warning, error) are covered
         - [ ] 1.6.4.3: Update or add tests for all logging scenarios to ensure correct backend is used and all event types are logged as expected
      5. [ ] Documentation
         - [ ] 1.6.5.1: Document new logging backend options and configuration
         - [ ] 1.6.5.2: Update usage examples and troubleshooting in README
         - [ ] 1.6.5.3: Document event log source registration and permissions
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
2. [ ] Migrate module configuration to YAML format
   1. [ ] Design YAML schema for module configuration (replace JSON)
   2. [ ] Update all config read/write functions to support YAML
   3. [ ] Update documentation and examples to use YAML
   4. [ ] Add tests for YAML config loading/saving
   5. [ ] Remove legacy JSON config support (if not needed)
3. [ ] Implement window state management: bring target window to front, restore if minimized, detect and handle window close/crash events
   1. [ ] Extend PowerShell Type Definitions for window state management
      - [ ] Add P/Invoke signature for `ShowWindow` (restore/minimize window)
      - [ ] Add P/Invoke signature for `SetForegroundWindow` (bring window to front)
      - [ ] Update `WindowEnumeration_TypeDefinition.ps1` accordingly
4. [ ] Implement emergency stop mechanisms:
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
