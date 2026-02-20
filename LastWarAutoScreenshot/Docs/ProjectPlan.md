# High-Level Task List for Auto Mouse Control Module

## Phase 1: Window Management & Safety

1. [x] Enumerate all open windows, including minimized and background apps, and allow user to select a target (e.g., LastWar.exe)
   1. [x] Design and create PowerShell Type Definitions for Win32 API window enumeration
      - [x] Define P/Invoke signatures for `EnumWindows` callback
      - [x] Define P/Invoke signatures for `GetWindowText` and `GetWindowTextLength`
      - [x] Define P/Invoke signatures for `IsWindowVisible`
      - [x] Define P/Invoke signatures for `GetWindowThreadProcessId`
      - [x] Define P/Invoke signatures for `IsIconic` (check if minimized)
      - [x] Define P/Invoke signatures for `GetForegroundWindow` (detect active window)
      - [x] Create `WindowEnumeration_TypeDefinition.ps1` in `LastWarAutoScreenshot/private/` folder
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

## Phase 2: Mouse Control & Automation

1. [ ] Implement mouse movement and click logic using `SendInput` Win32 API with window-relative percentage coordinate system
   1. [x] 1.1: Create `LastWarAutoScreenshot/src/MouseControlAPI.cs`
      - Namespace `LastWarAutoScreenshot`, class `MouseControlAPI`
      - Structs: `POINT`, `RECT`, `MOUSEINPUT`, `INPUT` (FieldOffset union layout for unmanaged interop)
      - Constants: `INPUT_MOUSE`, `MOUSEEVENTF_MOVE`, `MOUSEEVENTF_LEFTDOWN`, `MOUSEEVENTF_LEFTUP`
      - P/Invoke: `SendInput(uint nInputs, INPUT[] pInputs, int cbSize)`, `GetCursorPos(out POINT lpPoint)`, `GetWindowRect(IntPtr hWnd, out RECT lpRect)`
      - `SetLastError = true` on every DllImport; `CharSet.Auto` only where a string parameter is present
      - Note: step 4.1's `GetAsyncKeyState` is added to this same class in step 4 — no `CursorControl_TypeDefinitions.ps1` file is needed
   2. [x] 1.2: Update `LastWarAutoScreenshot.psm1`
      - Add `MouseControlAPI.cs` path to the existing `Add-Type -Path` call
      - Add `'LastWarAutoScreenshot.MouseControlAPI'` to the `$typeNames` guard array (prevents re-adding in the same session)
   3. [x] 1.3: Create `LastWarAutoScreenshot/Private/MouseControlHelpers.ps1`
      - `Invoke-SendMouseInput -DeltaX [int] -DeltaY [int] [-ButtonFlags [uint]]` — thin wrapper calling `[LastWarAutoScreenshot.MouseControlAPI]::SendInput`; logs Win32 error via `Write-LastWarLog` if return value = 0; returns $true/$false
      - `Invoke-GetCursorPosition` — thin wrapper calling `[LastWarAutoScreenshot.MouseControlAPI]::GetCursorPos`; returns `[PSCustomObject]@{X=[int]; Y=[int]}`
   4. [x] 1.4: Create `LastWarAutoScreenshot/Private/Get-WindowBounds.ps1`
      - `Invoke-GetWindowRect -WindowHandle [IntPtr]` — one-liner thin wrapper calling `[LastWarAutoScreenshot.MouseControlAPI]::GetWindowRect`
      - `Get-WindowBounds -WindowHandle [object]` — accepts IntPtr, int64, int, string (same handle-conversion pattern as `Set-WindowState`); calls `Invoke-GetWindowRect`; returns `[PSCustomObject]@{Left; Top; Right; Bottom; Width; Height}`; error handling + `Write-LastWarLog`
   5. [x] 1.5: Create `LastWarAutoScreenshot/Private/ConvertTo-ScreenCoordinates.ps1`
      - `ConvertTo-ScreenCoordinates -WindowHandle [object] -RelativeX [double] -RelativeY [double]`
      - Validates RelativeX and RelativeY are in range [0.0, 1.0]; logs error + returns `$null` if out-of-range
      - Calls `Get-WindowBounds`; computes `AbsoluteX = [int]($Bounds.Left + $RelativeX * $Bounds.Width)` and equivalent for Y
      - Returns `[PSCustomObject]@{X=[int]; Y=[int]}`
   6. [x] 1.6: Create `LastWarAutoScreenshot/Private/Move-MouseToPoint.ps1` (step 1 placeholder — replaced by `Invoke-MouseMovePath` in step 2)
      - `Move-MouseToPoint -X [int] -Y [int]`
      - Calls `Invoke-GetCursorPosition` to get current position; computes delta to target; calls `Invoke-SendMouseInput` with `MOUSEEVENTF_MOVE`
      - Returns $true/$false; red ANSI footer on failure; logs error via `Write-LastWarLog`
      - `.NOTES`: documents this as a placeholder; replaced by `Invoke-MouseMovePath` in step 2.5
   7. [x] 1.7: Create `LastWarAutoScreenshot/Private/Invoke-MouseClick.ps1`
      - `Invoke-MouseClick -X [int] -Y [int] [-DownDurationMs [int]]`
      - If X/Y differs from current cursor position, moves to X,Y first via `Move-MouseToPoint`
      - Reads `ClickDownDurationRangeMs` from config (random value within range) when `-DownDurationMs` is omitted
      - Calls `Invoke-SendMouseInput` for `MOUSEEVENTF_LEFTDOWN`, sleeps `DownDurationMs`, calls `Invoke-SendMouseInput` for `MOUSEEVENTF_LEFTUP`
      - Returns $true/$false; error handling + logging
   8. [x] 1.8: Add minimal `MouseControl` section to `LastWarAutoScreenshot/Private/ModuleConfig.json`
      - `"MouseControl": { "ClickDownDurationRangeMs": [50, 150] }` — full section added in step 2.1
   9. [x] 1.9: Update `LastWarAutoScreenshot/Private/Get-ModuleConfiguration.ps1` and `LastWarAutoScreenshot/Private/Save-ModuleConfiguration.ps1`
      - Handle new `MouseControl` key with defaults; no breaking changes to existing keys
   10. [x] 1.10: Create `LastWarAutoScreenshot/Public/Start-AutomationSequence.ps1` (skeleton)
       - `[CmdletBinding()]` parameters: `-WindowHandle [object]` (mandatory), `-RelativeX [double]`, `-RelativeY [double]`
       - Reads config `EmergencyStop.AutoStart`; calls `Start-EmergencyStopMonitor` if `$true`
       - Checks `$script:EmergencyStopRequested` — logs warning and exits cleanly if set before move
       - Calls `ConvertTo-ScreenCoordinates` → `Move-MouseToPoint` (step 1 placeholder; updated in step 2.6)
       - Checks `$script:EmergencyStopRequested` again after move — skips click and exits cleanly if set
       - Calls `Invoke-MouseClick`
       - `finally` block always calls `Stop-EmergencyStopMonitor`
       - Returns `[PSCustomObject]@{Success=[bool]; Message=[string]}`
       - `.NOTES`: documents step 2.6 as the upgrade point for human-like movement
   11. [x] 1.11: Update `LastWarAutoScreenshot.psd1`
       - Add `'Start-AutomationSequence'` to `FunctionsToExport`
   12. [ ] 1.12: Create `LastWarAutoScreenshot/Tests/MouseControl_TypeDefinition.Tests.ps1`
       - Verify `[LastWarAutoScreenshot.MouseControlAPI]` type loads without error
       - Verify `SendInput`, `GetCursorPos`, `GetWindowRect` static methods exist with correct signatures
       - Verify `POINT`, `RECT`, `MOUSEINPUT`, `INPUT` nested types exist and have expected public fields
   13. [ ] 1.13: Create `LastWarAutoScreenshot/Tests/MouseCoordinates.Tests.ps1`
       - `Get-WindowBounds`: mock `Invoke-GetWindowRect`; verify PSCustomObject shape; verify `Width = Right - Left`; verify error log + $false on Win32 failure
       - `ConvertTo-ScreenCoordinates`: mock `Get-WindowBounds`; verify correct absolute coordinates for several (x%, y%) values; verify `$null` + error log when input is outside [0.0, 1.0]
   14. [ ] 1.14: Create `LastWarAutoScreenshot/Tests/MouseMovement.Tests.ps1` (step 1 sections)
       - `Move-MouseToPoint`: mock `Invoke-GetCursorPosition` + `Invoke-SendMouseInput`; verify single SendInput call with correct delta; verify $false + error log on SendInput returning 0
       - `Invoke-MouseClick`: mock `Move-MouseToPoint` + `Invoke-SendMouseInput` + `Start-Sleep`; verify LEFTDOWN then LEFTUP calls with sleep between; verify config-derived duration used when `-DownDurationMs` omitted; verify $false + error log on failure
   15. [ ] 1.15: Create `LastWarAutoScreenshot/Tests/Start-AutomationSequence.Tests.ps1` (step 1 sections)
       - Mock `ConvertTo-ScreenCoordinates`, `Move-MouseToPoint`, `Invoke-MouseClick`, `Start-EmergencyStopMonitor`, `Stop-EmergencyStopMonitor`
       - `EmergencyStop.AutoStart = $true` → `Start-EmergencyStopMonitor` called
       - `$script:EmergencyStopRequested = $true` before move → exits cleanly; `Move-MouseToPoint` not called
       - `$script:EmergencyStopRequested = $true` after move → `Invoke-MouseClick` not called
       - `Stop-EmergencyStopMonitor` called in `finally` on both success and error paths
       - Correct PSCustomObject returned on success and failure
   16. [ ] 1.16: Run full Pester suite — all existing + new tests pass
2. [ ] Develop human-like mouse movement
   1. [ ] 2.1: Expand `LastWarAutoScreenshot/Private/ModuleConfig.json` with full `MouseControl` section (replaces the minimal step 1.8 entry)

      ```json
      "MouseControl": {
          "EasingEnabled": true,
          "OvershootEnabled": true,
          "OvershootFactor": 0.1,
          "MicroPausesEnabled": true,
          "MicroPauseChance": 0.2,
          "MicroPauseDurationRangeMs": [20, 80],
          "JitterEnabled": true,
          "JitterRadiusPx": 2,
          "BezierControlPointOffsetFactor": 0.3,
          "MovementDurationRangeMs": [200, 600],
          "ClickDownDurationRangeMs": [50, 150],
          "ClickPreDelayRangeMs": [50, 200],
          "ClickPostDelayRangeMs": [100, 300],
          "PathPointCount": 20
      }
      ```

   2. [ ] 2.2: Update `LastWarAutoScreenshot/Private/Get-ModuleConfiguration.ps1` and `LastWarAutoScreenshot/Private/Save-ModuleConfiguration.ps1`
      - Full `MouseControl` defaults; no breaking changes to existing keys
   3. [ ] 2.3: Add round-trip tests for all new config keys to `LastWarAutoScreenshot/Tests/ModuleConfiguration.Tests.ps1`
      - Verify all new defaults present when key is missing from file; verify save/load round-trip
   4. [ ] 2.4: Create `LastWarAutoScreenshot/Private/Get-BezierPoints.ps1`
      - `Get-BezierPoints -StartX [int] -StartY [int] -EndX [int] -EndY [int] [-NumPoints [int]] [-ControlPointOffsetFactor [double]] [-JitterRadiusPx [int]]`
      - All parameters default from config when omitted
      - `NumPoints` randomised ±20% before use (eliminates consistent step-interval timing signature)
      - Control point = midpoint + random perpendicular offset scaled by `ControlPointOffsetFactor × pathLength`
      - Bezier formula: `B(t) = (1−t)²·P₀ + 2(1−t)t·P₁ + t²·P₂` for t = 0..1 across `NumPoints` steps
      - Jitter: if `JitterEnabled`, add ±`JitterRadiusPx` random noise (integer) to each computed X, Y
      - Returns `[PSCustomObject[]]` each with integer `X` and `Y` properties
      - Pure `[math]` only — no `Add-Type`, no P/Invoke; fully testable
   5. [ ] 2.5: Create `LastWarAutoScreenshot/Private/Invoke-MouseMovePath.ps1`
      - `Invoke-MouseMovePath -Points [PSCustomObject[]]`
      - Total move duration: random within `MovementDurationRangeMs` config range
      - Ease-in/out: per-step delay derived from sinusoidal curve so movement is slow at start and end, fast mid-path
      - At each step: compute delta from previous point → `Invoke-SendMouseInput` → sleep step delay
      - Micro-pauses: after each step delay, with probability `MicroPauseChance` add an extra random sleep within `MicroPauseDurationRangeMs`
      - Overshoot: after main path completes, if `OvershootEnabled`, compute a small vector past the final point (scaled by `OvershootFactor × last-step-length`); execute a mini correction path back to the target using a second Bezier (no further overshoot on the correction move)
      - Returns $true/$false; logs any SendInput errors; red ANSI footer on failure
   6. [ ] 2.6: Update `LastWarAutoScreenshot/Public/Start-AutomationSequence.ps1`
      - Replace `Move-MouseToPoint` call with: `Invoke-GetCursorPosition` → `Get-BezierPoints` → `Invoke-MouseMovePath`
      - Add `ClickPreDelay` (random sleep within `ClickPreDelayRangeMs`) before `Invoke-MouseClick`
      - Add `ClickPostDelay` (random sleep within `ClickPostDelayRangeMs`) after `Invoke-MouseClick`
   7. [ ] 2.7: Add step 2 sections to `LastWarAutoScreenshot/Tests/MouseMovement.Tests.ps1`
      - `Get-BezierPoints`:
        - At least one intermediate point is non-collinear with start/end (confirms curve is not a straight line)
        - Returned count within ±40% of base `NumPoints` (accounts for ±20% randomisation)
        - All returned objects have integer `X` and `Y` properties
        - No `[LastWarAutoScreenshot.*]` type invocation (confirms pure `[math]` implementation)
      - `Invoke-MouseMovePath`:
        - Mock `Invoke-SendMouseInput` + `Start-Sleep`; verify `Invoke-SendMouseInput` called once per point
        - Ease-in/out: capture delay args to `Start-Sleep`; assert first + last delays are greater than median delay
        - `MicroPauseChance = 1.0`: extra `Start-Sleep` calls equal to point count
        - `OvershootEnabled = $true`: `Invoke-SendMouseInput` called beyond point count (extra correction path)
        - SendInput failure: error logged, no unhandled exception
   8. [ ] 2.8: Add step 2 sections to `LastWarAutoScreenshot/Tests/Start-AutomationSequence.Tests.ps1`
      - Verify `Invoke-MouseMovePath` called instead of `Move-MouseToPoint`
      - Verify `ClickPreDelay` and `ClickPostDelay` `Start-Sleep` calls are present
   9. [ ] 2.9: Run full Pester suite — all existing + new tests pass
   10. [ ] 2.10: Update `LastWarAutoScreenshot/Docs/README.md`
       - Document all `MouseControl` config keys with types, defaults, and examples
       - Document human-like movement behaviour: Bezier path shaping, ease-in/out, jitter, micro-pauses, overshoot/correction
3. [ ] Allow user to define bounding box or circle as cursor target; randomly select position within defined area for each action
   1. [ ] 3.1: Create `LastWarAutoScreenshot/Private/Get-RandomTargetPosition.ps1`
      - Two `[CmdletBinding()]` parameter sets:
        - **Box**: `-Box [PSCustomObject]` with properties `RelativeX`, `RelativeY`, `RelativeWidth`, `RelativeHeight` (all 0.0–1.0) — uniform random within `[RelativeX, RelativeX+RelativeWidth] × [RelativeY, RelativeY+RelativeHeight]`
        - **Circle**: `-Circle [PSCustomObject]` with `RelativeCentreX`, `RelativeCentreY`, `RelativeRadius` — `angle = 2π × random`, `r = √random × RelativeRadius` (sqrt ensures uniform density, not concentrated at centre), `X = CentreX + r·cos(angle)`, `Y = CentreY + r·sin(angle)`
      - Output clamped to [0.0, 1.0] on both axes
      - Returns `[PSCustomObject]@{RelativeX=[double]; RelativeY=[double]}` or `$null` with error log on invalid input
      - Pure PowerShell — no `Add-Type`
   2. [ ] 3.2: Create `LastWarAutoScreenshot/Tests/Get-RandomTargetPosition.Tests.ps1`
      - Box: 100-iteration loop — all returned points within `[RelativeX, RelativeX+RelativeWidth]` × `[RelativeY, RelativeY+RelativeHeight]`
      - Circle: 100-iteration loop — all returned points within `RelativeRadius` of centre
      - Circle distribution: mean of 100 points clusters near centre (within 10% of radius on each axis)
      - Invalid input (negative radius, region values outside [0.0, 1.0]) → `$null` returned + error logged
      - Clamp: no returned value is below 0.0 or above 1.0
   3. [ ] 3.3: Update `LastWarAutoScreenshot/Public/Start-AutomationSequence.ps1`
      - Add optional `-Region [PSCustomObject]` parameter via parameter sets (mutually exclusive with `-RelativeX`/`-RelativeY`)
      - If `-Region` provided: call `Get-RandomTargetPosition` to obtain `RelativeX`, `RelativeY`
      - If scalar `-RelativeX`/`-RelativeY` provided: use directly
      - Both paths produce a single (RelativeX, RelativeY) pair before `ConvertTo-ScreenCoordinates`; downstream logic unchanged
   4. [ ] 3.4: Add step 3 sections to `LastWarAutoScreenshot/Tests/Start-AutomationSequence.Tests.ps1`
      - Mock `Get-RandomTargetPosition`; verify called when `-Region` is provided
      - Verify `Get-RandomTargetPosition` not called when scalar `-RelativeX`/`-RelativeY` are provided
   5. [ ] 3.5: Run full Pester suite — new test count meets or exceeds the pre-steps-1–3 baseline
   6. [ ] 3.6: Update `LastWarAutoScreenshot/Docs/README.md`
      - Document `-Region` parameter with Box and Circle formats, field descriptions, and usage examples
4. [ ] Implement emergency stop mechanisms (DEFERRED — implement after Mouse Control step 1 is complete):

   **Hotkey mechanism**

   4.1. [ ] Add `GetAsyncKeyState` P/Invoke to `LastWarAutoScreenshot/src/MouseControlAPI.cs` (created in step 1.1)
      - Add single `GetAsyncKeyState(int vKey)` DllImport method to the existing `LastWarAutoScreenshot.MouseControlAPI` C# class — no new files or types
      - All references to `[Win32.MouseControl]::` in steps 4.3–4.5 use `[LastWarAutoScreenshot.MouseControlAPI]::` to match the established namespace convention
      - Note: the virtual key code for `#` is keyboard-layout-dependent (`VK_OEM_5` = 0xDC on UK layouts; Shift+3 on US layouts) — document this in code comments and README
      - Pester test for the type definition goes in `LastWarAutoScreenshot/Tests/MouseControl_TypeDefinition.Tests.ps1` (created in step 1.12); add a test verifying `GetAsyncKeyState` exists on the type and is callable with a known safe key code (e.g. VK_SHIFT = 0x10)

   4.2. [ ] Add emergency stop settings to module configuration
      - Add `EmergencyStop.HotkeyVKeyCodes` (int array, default: [0x11, 0x10, 0xDC] — Ctrl, Shift, # on UK layout)
      - Add `EmergencyStop.PollIntervalMs` (int, default: 100)
      - Add `EmergencyStop.AutoStart` (bool, default: true — monitor auto-starts when the automation sequence starts)
      - Update `ModuleConfig.json` with new keys and defaults
      - Update `Get-ModuleConfiguration` and `Save-ModuleConfiguration` to handle new keys (no breaking changes)
      - Update `ModuleConfiguration.Tests.ps1` to cover new config keys (round-trip save/load, defaults)

   4.3. [ ] Implement `Invoke-EmergencyStopPoll` (private)
      - Same extracted-poll pattern as `Invoke-MonitorPoll` — exists solely to make the timer callback testable without physical keypresses
      - Parameter: `$State` hashtable with keys: `Stopped` (bool), `Timer` (System.Timers.Timer), `HotkeyVKeyCodes` (int[]), `GetKeyStateFn` (ScriptBlock — injectable mock; defaults to `[LastWarAutoScreenshot.MouseControlAPI]::GetAsyncKeyState($vKey)` when $null)
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

## Phase 3: GUI & Recording

1. [ ] Design and implement GUI for:
   - Interactive recording of mouse actions (move, click, drag)
   - Visual selection of screenshot regions
   - Configuration of emergency stop hotkeys
   - Display of local storage usage (GB) with progress bar
   - "Logging" tab for verbosity configuration
   - Retry logic configuration for failures
2. [ ] Implement action recording that generates user settings in module configuration (JSON import/export supported)
3. [ ] Enable manual editing, saving, and importing of configuration files

## Phase 4: Configuration & Scheduling

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

## Phase 5: Screenshot Management

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

## Phase 6: Module Installation & Versioning

1. [ ] Implement PowerShell v7 best practices for module installation:

- Support installation to user and system module paths
- Proper module manifest (psd1) with metadata
- Exported functions defined in manifest (as developed)
- Semantic versioning for module releases

1. [ ] Create installation documentation and example commands

## Phase 7: Documentation & Examples

1. [ ] Create example configuration files with inline comments
2. [ ] Document window-relative coordinate system
3. [ ] Provide quick start guide with simple working example
4. [ ] Document all exported PowerShell functions as they are created

## Phase 8: Azure Integration (Future)

1. [ ] Prepare for future Azure Blob upload integration:

- Design extensible screenshot saving logic
- SAS token-based authentication
- Exponential backoff with jitter for upload retry logic
- Configurable retry attempts
- Upload failure handling with same retry logic as other operations
