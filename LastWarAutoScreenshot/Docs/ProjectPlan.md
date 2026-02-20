# High-Level Task List for Auto Mouse Control Module

## Window Management & Safety

1. [x] Enumerate all open windows, including minimized and background apps, and allow user to select a target (e.g., LastWar.exe)
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
        - [x] 1.5.5: General Error Logging Consistency
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
   6. [x] Add Windows Event Logging
      1. [x] Design Logging Backend Abstraction
         - [x] 1.6.1.1: Define interface/contract for logging backends (event log, file, etc.)
         - [x] 1.6.1.2: Update logging helper functions to use backend abstraction (now script-based, not class-based)
         - [x] 1.6.1.3: Add configuration option to select logging backend (event log, file, both)
         - [x] 1.6.1.4: Document backend selection in module configuration schema
         - [x] 1.6.1.5: Create unit tests for backend abstraction and configuration logic
      2. [x] Implement Windows Event Log Backend
         - [x] 1.6.2.1: Register custom event log source ("LastWarAutoScreenshot") if not present
         - [x] 1.6.2.2: Implement event log writing using PowerShell Write-EventLog (with fallback/error handling)
         - [x] 1.6.2.3: Define event types and IDs for verbose, info, warning, error
         - [x] 1.6.2.4: Ensure all log fields (PID, WindowHandle, etc.) are included in event details
         - [x] 1.6.2.5: Add logic to handle permission errors (e.g., fallback to Application log or prompt user)
         - [x] 1.6.2.6: Create unit tests for event log backend, including source registration, event writing, error handling, and field coverage
      3. [x] Implement Local File Logging Backend Enhancements
         - [x] 1.6.3.1: Add log file rollover (by size, count, or age; configurable)
         - [x] 1.6.3.2: Implement cleanup of old log files based on retention policy
         - [x] 1.6.3.3: Ensure log format matches documented standard
         - [x] 1.6.3.4: Make rollover and retention settings configurable in module configuration
         - [x] 1.6.3.5: Create unit tests for file logging enhancements, including rollover, cleanup, and format validation
      4. [x] Update Logging Calls Throughout Codebase
          - [x] 1.6.4.1: Audit all existing logging calls and document locations/functions needing update
          - [x] 1.6.4.2: Refactor logging in each file (incremental, mark each as complete after tests pass):
             - [x] 1.6.4.2.1: Refactor logging in public functions (file-by-file)
             - [x] 1.6.4.2.2: Refactor logging in private/helper functions (file-by-file)
             - [x] 1.6.4.2.3: Refactor logging in error handling paths (file-by-file)
          - [x] 1.6.4.3: Review and ensure all event types (verbose, info, warning, error) are used appropriately in each function
          - [x] 1.6.4.4: Add/Update Pester tests for each logging scenario and backend (success and failure/error for each backend)
          - [x] 1.6.4.5: Validate test coverage for logging (aim for 100% of loggable paths)
      5. [x] Documentation
         - [x] 1.6.5.1: Document new logging backend options and configuration keys in Logging.md
         - [x] 1.6.5.2: Add PowerShell command-line usage examples for configuring and using logging backends (Logging.md)
         - [x] 1.6.5.3: Add troubleshooting section to Logging.md covering:
             - Permissions errors (file and event log)
             - Log file locations
             - Backend selection issues
         - [x] 1.6.5.4: Document event log source registration and permissions for both user and admin install scenarios (Logging.md)
         - [x] 1.6.5.5: Add screenshots, diagrams, and step-by-step walkthroughs for logging configuration and troubleshooting, following best practices and examples from popular projects (Logging.md)
         - [x] 1.6.5.6: Ensure all documentation is clear and targeted at gamers who are also developers
   7. [x] Create Pester unit tests
      - [x] Mock Win32 API calls for enumeration function tests
      - [x] Test filtering logic with various window states
      - [x] Test console menu input validation (valid, invalid, cancel)
      - [x] Test configuration save/load logic
      - [x] Test error handling scenarios
      - [x] Achieve minimum 80% code coverage
   8. [x] Update README.md
      - [x] Document new exported functions (if any made public)
      - [x] Update "Features" section to reflect window enumeration capabilities
      - [x] Add usage examples for window selection workflow
      - [x] Document configuration schema for window target settings
2. [x] Implement window state management: bring target window to front, restore if minimized, detect and handle window close/crash events
   1. [x] Extend PowerShell Type Definitions for window state management
      - [x] 2.1.1: Add P/Invoke signature for `ShowWindow` (support only minimize and maximize)
        - Only implement support for minimize and maximize window states (not restore or others)
        - Follow existing error handling and logging patterns
      - [x] 2.1.2: Add P/Invoke signature for `SetForegroundWindow` (bring window to front)
      - [x] 2.1.3: Update `WindowEnumeration_TypeDefinition.ps1` accordingly
      - [x] 2.1.4: Create Pester unit tests for new type definitions (ensure direct tests for type and method signatures)
   2. [x] Implement window state management functions
      - [x] 2.2.1: Create `Set-WindowState` (minimize/maximize window by handle)
        - Implement as a helper function to call ShowWindow for testability
        - Use approved PowerShell verbs and best practices for naming
      - [x] 2.2.2: Create `Set-WindowActive` (bring window to foreground by handle, optionally by WindowName or ProcessID)
        - Name function Set-WindowActive (not Activate-Window)
        - Parameters: same as Set-WindowState, plus optional WindowName or ProcessID
        - Provide user-facing feedback and log errors using conventions from Set-WindowState
        - Return $true on success, $false on failure
        - Display errors in red text in console footer
        - Pester tests for helper function and type definition, as with Set-WindowState
      - [x] 2.2.3: Add comment-based help and usage examples
      - [x] 2.2.4: Add error handling for all Win32 API calls (try/catch, log errors)
      - [x] 2.2.5: Provide user-facing feedback for all state changes (success/failure), display errors in red text in a console footer with a note to check event log or local log file for details
      - [x] 2.2.6: Log all errors using the standard logging backend
      - [x] 2.2.7: Create Pester unit tests for all new functions and error scenarios (include both type definition and helper function tests)
   3. [x] Implement window close/crash detection and handling (polling)
      - [x] 2.3.1: Use polling to check if the window handle is still valid (window close detection)
      - [x] 2.3.2: Implement process exit/crash detection using polling (not .NET event subscription) due to PowerShell runspace/test limitations
      - [x] 2.3.3: Detection of window closure or process exit should run continuously once started, until a function is called to stop it, or it dies and triggers error handling with retry/abort logic
      - [x] 2.3.4: If window is closed or process exits, prompt user to retry or abort; log as error
      - [x] 2.3.5: Provide user-facing feedback for all detection events (red text footer, log reference)
      - [x] 2.3.6: Document in code and README.md that true Win32 event hooks are not used due to complexity and maintainability concerns
        - In-code documentation added to both `Invoke-MonitorPoll` and `Start-WindowAndProcessMonitor` (.NOTES sections)
        - README.md Window Management section updated with polling rationale
      - [x] 2.3.7: Create Pester unit tests for detection and handling logic
   4. [x] Documentation
      - [x] 2.4.1: Document new functions and usage in README.md
      - [x] 2.4.2: Add usage and troubleshooting examples for window state management

## Mouse Control & Interaction

1. [ ] Implement mouse movement and click logic using Windows API or System.Windows.Forms with window-relative coordinate system
2. [ ] Develop human-like mouse movement with:
   - Randomized delays and variable timing to mimic human behaviour
   - Curved paths (not straight lines) to avoid bot detection
   - Configurable speed ranges and randomness factors
   - Variable duration between mouse-up and mouse-down events
3. [ ] Allow user to define bounding box or circle as cursor target; randomly select position within defined area for each action
4. [ ] Implement emergency stop mechanisms (DEFERRED — implement after Mouse Control step 1 is complete):

   **Hotkey mechanism**

   4.1. [ ] Add `GetAsyncKeyState` P/Invoke to `CursorControl_TypeDefinitions.ps1`
      - Add single `GetAsyncKeyState(int vKey)` DllImport method to the existing `Win32.MouseControl` C# class — no new files or types
      - Note: the virtual key code for `#` is keyboard-layout-dependent (`VK_OEM_5` = 0xDC on UK layouts; Shift+3 on US layouts) — document this in code comments and README
      - Write Pester test verifying the method exists on the type and is callable with a known safe key code (e.g. VK_SHIFT = 0x10)

   4.2. [ ] Add emergency stop settings to module configuration
      - Add `EmergencyStop.HotkeyVKeyCodes` (int array, default: [0x11, 0x10, 0xDC] — Ctrl, Shift, # on UK layout)
      - Add `EmergencyStop.PollIntervalMs` (int, default: 100)
      - Add `EmergencyStop.AutoStart` (bool, default: true — monitor auto-starts when the automation sequence starts)
      - Update `ModuleConfig.json` with new keys and defaults
      - Update `Get-ModuleConfiguration` and `Save-ModuleConfiguration` to handle new keys (no breaking changes)
      - Update `ModuleConfiguration.Tests.ps1` to cover new config keys (round-trip save/load, defaults)

   4.3. [ ] Implement `Invoke-EmergencyStopPoll` (private)
      - Same extracted-poll pattern as `Invoke-MonitorPoll` — exists solely to make the timer callback testable without physical keypresses
      - Parameter: `$State` hashtable with keys: `Stopped` (bool), `Timer` (System.Timers.Timer), `HotkeyVKeyCodes` (int[]), `GetKeyStateFn` (ScriptBlock — injectable mock; defaults to `[Win32.MouseControl]::GetAsyncKeyState($vKey)` when $null)
      - Early-return if `$State.Stopped -eq $true`
      - Check each VKey code via `GetKeyStateFn`; test the high-order bit (0x8000) — key currently held down, not the "pressed since last call" bit
      - If all keys held: set `$script:EmergencyStopRequested = $true`, set `$State.Stopped = $true`, stop timer, log Error via `Write-LastWarLog`, write red ANSI console message advising user to check logs
      - Write Pester tests covering:
         - All keys held → flag set, timer stopped, log called, red console message written
         - Partial key hold → no action taken
         - No keys held → no action taken
         - `$State.Stopped` already `$true` → returns immediately, nothing else called
         - `GetKeyStateFn` throws → error logged, no unhandled exception

   4.4. [ ] Implement `Start-EmergencyStopMonitor` (public)
      - `[CmdletBinding()]` with optional parameters: `-PollIntervalMs` (int), `-HotkeyVKeyCodes` (int[]) — both read from module config when omitted
      - Idempotent: if `$script:EmergencyStopTimer` is already running, log Info `"Emergency stop monitor is already running — ignoring duplicate start"` and return without starting a second timer
      - On a clean start: reset `$script:EmergencyStopRequested = $false`
      - Build `$State` hashtable; create and start `System.Timers.Timer` with `AutoReset = $true`; store in `$script:EmergencyStopTimer`; Elapsed handler calls `Invoke-EmergencyStopPoll` via `.GetNewClosure()`
      - Return `[PSCustomObject]` with `Stop` and `Cleanup` scriptblocks (same contract as `Start-WindowAndProcessMonitor`)
      - Add full comment-based help including `.NOTES` documenting: why polling is used over `RegisterHotKey`, the re-arming requirement, and that automation loop integration is in Mouse Control step 1
      - Write Pester tests:
         - First call starts timer, `$script:EmergencyStopRequested` reset to `$false`, correct object returned
         - Second call logs Info and returns without starting another timer
         - Config defaults used when parameters are omitted
         - Returned `Stop` scriptblock sets `$State.Stopped = $true` and stops the timer

   4.5. [ ] Implement `Stop-EmergencyStopMonitor` (public)
      - Stops and disposes `$script:EmergencyStopTimer`; sets `$script:EmergencyStopTimer = $null`
      - Does NOT reset `$script:EmergencyStopRequested` — document clearly: callers must reset the flag manually before re-arming
      - Log Info `"Emergency stop monitor stopped"` via `Write-LastWarLog`
      - Calling when already stopped must not throw
      - Add full comment-based help
      - Write Pester tests:
         - Timer stopped and variable nulled
         - `$script:EmergencyStopRequested` not modified by this call
         - Log call verified via mock
         - Calling when monitor is not running does not throw

   **Mouse gesture mechanism**

   4.6. [ ] Implement mouse gesture detection: hold both mouse buttons for 3 seconds
      - DEFERRED: depends on Mouse Control steps 1 and 2 (automation loop must exist)
      - Detect simultaneous left and right mouse button hold using `GetAsyncKeyState` (VK_LBUTTON 0x01, VK_RBUTTON 0x02) — reuse same poll infrastructure from 4.3
      - Count consecutive polls where both buttons are held; trigger after 3 seconds worth of poll intervals (3000 / PollIntervalMs ticks)
      - On trigger: same behaviour as hotkey (set `$script:EmergencyStopRequested`, log Error, red console message)
      - Write Pester tests via injected mock with a counter simulating consecutive held polls

   **Integration**

   4.7. [ ] Integration point — implement as part of Mouse Control step 1
      - If `$Config.EmergencyStop.AutoStart -eq $true`, automation sequence start function calls `Start-EmergencyStopMonitor`
      - Each iteration of the automation loop checks `if ($script:EmergencyStopRequested)` and exits gracefully with cleanup if true
      - Automation sequence end/cleanup calls `Stop-EmergencyStopMonitor`

   4.8. [ ] Run full Pester test suite; confirm test count meets or exceeds the pre-task baseline before marking any sub-task complete

   4.9. [ ] Update README.md
      - Document `Start-EmergencyStopMonitor` and `Stop-EmergencyStopMonitor` with usage examples
      - Document the default hotkey (`Ctrl+Shift+#`), how to change it via config, and the keyboard-layout caveat for the `#` key VKCode
      - Document `$script:EmergencyStopRequested`: what sets it, what reads it, and the re-arming requirement
      - Document all three config keys (`HotkeyVKeyCodes`, `PollIntervalMs`, `AutoStart`) with types, defaults, and examples

## GUI & Recording

1. [ ] Design and implement GUI for:
   - Interactive recording of mouse actions (move, click, drag)
   - Visual selection of screenshot regions
   - Configuration of emergency stop hotkeys
   - Display of local storage usage (GB) with progress bar
   - "Logging" tab for verbosity configuration
   - Retry logic configuration for failures
2. [ ] Implement action recording that generates user settings in module configuration (JSON import/export supported)
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
