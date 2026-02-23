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

1. [x] Implement mouse movement and click logic using `SendInput` Win32 API with window-relative percentage coordinate system
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
   12. [x] 1.12: Create `LastWarAutoScreenshot/Tests/MouseControl_TypeDefinition.Tests.ps1`
       - Verify `[LastWarAutoScreenshot.MouseControlAPI]` type loads without error
       - Verify `SendInput`, `GetCursorPos`, `GetWindowRect` static methods exist with correct signatures
       - Verify `POINT`, `RECT`, `MOUSEINPUT`, `INPUT` nested types exist and have expected public fields
   13. [x] 1.13: Create `LastWarAutoScreenshot/Tests/MouseCoordinates.Tests.ps1`
       - `Get-WindowBounds`: mock `Invoke-GetWindowRect`; verify PSCustomObject shape; verify `Width = Right - Left`; verify error log + $false on Win32 failure
       - `ConvertTo-ScreenCoordinates`: mock `Get-WindowBounds`; verify correct absolute coordinates for several (x%, y%) values; verify `$null` + error log when input is outside [0.0, 1.0]
   14. [x] 1.14: Create `LastWarAutoScreenshot/Tests/MouseMovement.Tests.ps1` (step 1 sections)
       - `Move-MouseToPoint`: mock `Invoke-GetCursorPosition` + `Invoke-SendMouseInput`; verify single SendInput call with correct delta; verify $false + error log on SendInput returning 0
       - `Invoke-MouseClick`: mock `Move-MouseToPoint` + `Invoke-SendMouseInput` + `Start-Sleep`; verify LEFTDOWN then LEFTUP calls with sleep between; verify config-derived duration used when `-DownDurationMs` omitted; verify $false + error log on failure
   15. [x] 1.15: Create `LastWarAutoScreenshot/Tests/Start-AutomationSequence.Tests.ps1` (step 1 sections)
       - Mock `ConvertTo-ScreenCoordinates`, `Move-MouseToPoint`, `Invoke-MouseClick`, `Start-EmergencyStopMonitor`, `Stop-EmergencyStopMonitor`
       - `EmergencyStop.AutoStart = $true` → `Start-EmergencyStopMonitor` called
       - `$script:EmergencyStopRequested = $true` before move → exits cleanly; `Move-MouseToPoint` not called
       - `$script:EmergencyStopRequested = $true` after move → `Invoke-MouseClick` not called
       - `Stop-EmergencyStopMonitor` called in `finally` on both success and error paths
       - Correct PSCustomObject returned on success and failure
   16. [x] 1.16: Run full Pester suite — all existing + new tests pass
2. [x] Develop human-like mouse movement
   1. [x] 2.1: Expand `LastWarAutoScreenshot/Private/ModuleConfig.json` with full `MouseControl` section (replaces the minimal step 1.8 entry)

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

   2. [x] 2.2: Update `LastWarAutoScreenshot/Private/Get-ModuleConfiguration.ps1` and `LastWarAutoScreenshot/Private/Save-ModuleConfiguration.ps1`
      - Full `MouseControl` defaults; no breaking changes to existing keys
   3. [x] 2.3: Add round-trip tests for all new config keys to `LastWarAutoScreenshot/Tests/ModuleConfiguration.Tests.ps1`
      - Verify all new defaults present when key is missing from file; verify save/load round-trip
   4. [x] 2.4: Create `LastWarAutoScreenshot/Private/Get-BezierPoints.ps1`
      - `Get-BezierPoints -StartX [int] -StartY [int] -EndX [int] -EndY [int] [-NumPoints [int]] [-ControlPointOffsetFactor [double]] [-JitterRadiusPx [int]]`
      - All parameters default from config when omitted
      - `NumPoints` randomised ±20% before use (eliminates consistent step-interval timing signature)
      - Control point = midpoint + random perpendicular offset scaled by `ControlPointOffsetFactor × pathLength`
      - Bezier formula: `B(t) = (1−t)²·P₀ + 2(1−t)t·P₁ + t²·P₂` for t = 0..1 across `NumPoints` steps
      - Jitter: if `JitterEnabled`, add ±`JitterRadiusPx` random noise (integer) to each computed X, Y
      - Returns `[PSCustomObject[]]` each with integer `X` and `Y` properties
      - Pure `[math]` only — no `Add-Type`, no P/Invoke; fully testable
   5. [x] 2.5: Create `LastWarAutoScreenshot/Private/Invoke-MouseMovePath.ps1`
      - `Invoke-MouseMovePath -Points [PSCustomObject[]]`
      - Total move duration: random within `MovementDurationRangeMs` config range
      - Ease-in/out: per-step delay derived from sinusoidal curve so movement is slow at start and end, fast mid-path
      - At each step: compute delta from previous point → `Invoke-SendMouseInput` → sleep step delay
      - Micro-pauses: after each step delay, with probability `MicroPauseChance` add an extra random sleep within `MicroPauseDurationRangeMs`
      - Overshoot: after main path completes, if `OvershootEnabled`, compute a small vector past the final point (scaled by `OvershootFactor × last-step-length`); execute a mini correction path back to the target using a second Bezier (no further overshoot on the correction move)
      - Returns $true/$false; logs any SendInput errors; red ANSI footer on failure
   6. [x] 2.6: Update `LastWarAutoScreenshot/Public/Start-AutomationSequence.ps1`
      - Replace `Move-MouseToPoint` call with: `Invoke-GetCursorPosition` → `Get-BezierPoints` → `Invoke-MouseMovePath`
      - Add `ClickPreDelay` (random sleep within `ClickPreDelayRangeMs`) before `Invoke-MouseClick`
      - Add `ClickPostDelay` (random sleep within `ClickPostDelayRangeMs`) after `Invoke-MouseClick`
   7. [x] 2.7: Add step 2 sections to `LastWarAutoScreenshot/Tests/MouseMovement.Tests.ps1`
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
   8. [x] 2.8: Add step 2 sections to `LastWarAutoScreenshot/Tests/Start-AutomationSequence.Tests.ps1`
      - Verify `Invoke-MouseMovePath` called instead of `Move-MouseToPoint`
      - Verify `ClickPreDelay` and `ClickPostDelay` `Start-Sleep` calls are present
   9. [x] 2.9: Run full Pester suite — all existing + new tests pass
   10. [x] 2.10: Update `LastWarAutoScreenshot/Docs/README.md`
       - Document all `MouseControl` config keys with types, defaults, and examples
       - Document human-like movement behaviour: Bezier path shaping, ease-in/out, jitter, micro-pauses, overshoot/correction
3. [x] Allow user to define bounding box or circle as cursor target; randomly select position within defined area for each action
   1. [x] 3.1: Create `LastWarAutoScreenshot/Private/Get-RandomTargetPosition.ps1`
      - Two `[CmdletBinding()]` parameter sets:
        - **Box**: `-Box [PSCustomObject]` with properties `RelativeX`, `RelativeY`, `RelativeWidth`, `RelativeHeight` (all 0.0–1.0) — uniform random within `[RelativeX, RelativeX+RelativeWidth] × [RelativeY, RelativeY+RelativeHeight]`
        - **Circle**: `-Circle [PSCustomObject]` with `RelativeCentreX`, `RelativeCentreY`, `RelativeRadius` — `angle = 2π × random`, `r = √random × RelativeRadius` (sqrt ensures uniform density, not concentrated at centre), `X = CentreX + r·cos(angle)`, `Y = CentreY + r·sin(angle)`
      - Output clamped to [0.0, 1.0] on both axes
      - Returns `[PSCustomObject]@{RelativeX=[double]; RelativeY=[double]}` or `$null` with error log on invalid input
      - Pure PowerShell — no `Add-Type`
   2. [x] 3.2: Create `LastWarAutoScreenshot/Tests/Get-RandomTargetPosition.Tests.ps1`
      - Box: 100-iteration loop — all returned points within `[RelativeX, RelativeX+RelativeWidth]` × `[RelativeY, RelativeY+RelativeHeight]`
      - Circle: 100-iteration loop — all returned points within `RelativeRadius` of centre
      - Circle distribution: mean of 100 points clusters near centre (within 10% of radius on each axis)
      - Invalid input (negative radius, region values outside [0.0, 1.0]) → `$null` returned + error logged
      - Clamp: no returned value is below 0.0 or above 1.0
   3. [x] 3.3: Update `LastWarAutoScreenshot/Public/Start-AutomationSequence.ps1`
      - Add optional `-Region [PSCustomObject]` parameter via parameter sets (mutually exclusive with `-RelativeX`/`-RelativeY`)
      - If `-Region` provided: call `Get-RandomTargetPosition` to obtain `RelativeX`, `RelativeY`
      - If scalar `-RelativeX`/`-RelativeY` provided: use directly
      - Both paths produce a single (RelativeX, RelativeY) pair before `ConvertTo-ScreenCoordinates`; downstream logic unchanged
   4. [x] 3.4: Add step 3 sections to `LastWarAutoScreenshot/Tests/Start-AutomationSequence.Tests.ps1`
      - Mock `Get-RandomTargetPosition`; verify called when `-Region` is provided
      - Verify `Get-RandomTargetPosition` not called when scalar `-RelativeX`/`-RelativeY` are provided
   5. [x] 3.5: Run full Pester suite — new test count meets or exceeds the pre-steps-1–3 baseline
   6. [x] 3.6: Update `LastWarAutoScreenshot/Docs/README.md`
      - Document `-Region` parameter with Box and Circle formats, field descriptions, and usage examples
4. [x] Implement emergency stop mechanisms
   1. [x] Add `GetAsyncKeyState` P/Invoke to `LastWarAutoScreenshot/src/MouseControlAPI.cs` (created in step 1.1)
      - Add single `GetAsyncKeyState(int vKey)` DllImport method to the existing `LastWarAutoScreenshot.MouseControlAPI` C# class — no new files or types
      - All references to `[Win32.MouseControl]::` in steps 4.3–4.5 use `[LastWarAutoScreenshot.MouseControlAPI]::` to match the established namespace convention
      - Note: the virtual key code for `#` is keyboard-layout-dependent (`VK_OEM_5` = 0xDC on UK layouts; Shift+3 on US layouts) — document this in code comments and README
      - Pester test for the type definition goes in `LastWarAutoScreenshot/Tests/MouseControl_TypeDefinition.Tests.ps1` (created in step 1.12); add a test verifying `GetAsyncKeyState` exists on the type and is callable with a known safe key code (e.g. VK_SHIFT = 0x10)
   2. [x] Add emergency stop settings to module configuration
      - Add `EmergencyStop.HotkeyVKeyCodes` (int array, default: [0x11, 0x10, 0xDC] — Ctrl, Shift, # on UK layout)
      - Add `EmergencyStop.PollIntervalMs` (int, default: 100)
      - Add `EmergencyStop.AutoStart` (bool, default: true — monitor auto-starts when the automation sequence starts)
      - Update `ModuleConfig.json` with new keys and defaults
      - Update `Get-ModuleConfiguration` and `Save-ModuleConfiguration` to handle new keys (no breaking changes)
      - Update `ModuleConfiguration.Tests.ps1` to cover new config keys (round-trip save/load, defaults)
   3. [x] Implement `Invoke-EmergencyStopPoll` (private)
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
   4. [x] Implement `Start-EmergencyStopMonitor` (public)
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
   5. [x] Implement `Stop-EmergencyStopMonitor` (public)
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
   6. [x] Implement mouse gesture detection: hold both mouse buttons for 3 seconds
      - Detect simultaneous left and right mouse button hold using `GetAsyncKeyState` (VK_LBUTTON 0x01, VK_RBUTTON 0x02) — reuse same poll infrastructure from 4.3
      - Count consecutive polls where both buttons are held; trigger after 3 seconds worth of poll intervals (3000 / PollIntervalMs ticks)
      - On trigger: same behaviour as hotkey (set `$script:EmergencyStopRequested`, log Error, red console message)
      - Write Pester tests via injected mock with a counter simulating consecutive held polls
   7. [x] Integration point — implement as part of Mouse Control step 1
      - If `$Config.EmergencyStop.AutoStart -eq $true`, automation sequence start function calls `Start-EmergencyStopMonitor`
      - Each iteration of the automation loop checks `if ($script:EmergencyStopRequested)` and exits gracefully with cleanup if true
      - Automation sequence end/cleanup calls `Stop-EmergencyStopMonitor`
   8. [x] Run full Pester test suite; confirm test count meets or exceeds the pre-task baseline before marking any sub-task complete
   9. [x] Update README.md
   10. [x] Move hardcoded module configuration values out of `Start-EmergencyStopMonitor`; make `Get-ModuleConfiguration` the single source of truth
       - `Get-ModuleConfiguration` must never return `$null`; when the config file does not exist it creates one at the default path containing only the module-settings sections (Logging, MouseControl, EmergencyStop) with all defaults, logs an Info message, and returns the defaults object (required window-property validation is skipped for a fresh defaults-only file)
       - Remove the hardcoded `$effectivePollIntervalMs = 100` and `$effectiveHotkeyVKeyCodes = @(0x11, 0x10, 0xDC)` fallback constants from `Start-EmergencyStopMonitor`; remove the surrounding `try/catch` that guarded the config load; call `Get-ModuleConfiguration` directly and use `$config.EmergencyStop.PollIntervalMs` / `$config.EmergencyStop.HotkeyVKeyCodes`
       - Update `ModuleConfiguration.Tests.ps1`: replace the "returns `$null` when file does not exist" tests with tests that assert a default config is created and returned; add `AfterEach` cleanup for the generated file; add a test that verifies `Get-ModuleConfiguration` creates the config file on disk
       - Update `EmergencyStop.Tests.ps1` (if needed): add a test asserting that `Start-EmergencyStopMonitor` propagates an error when `Get-ModuleConfiguration` throws; remove any test that relied on the hardcoded fallback path
      - Document `Start-EmergencyStopMonitor` and `Stop-EmergencyStopMonitor` with usage examples
      - Document the default hotkey (`Ctrl+Shift+#`), how to change it via config, and the keyboard-layout caveat for the `#` key VKCode
      - Document `$script:EmergencyStopRequested`: what sets it, what reads it, and the re-arming requirement
      - Document all three config keys (`HotkeyVKeyCodes`, `PollIntervalMs`, `AutoStart`) with types, defaults, and examples

## Phase 3: Design & Build Console App

### Architecture decisions (record here for future reference)

- **UI library:** Spectre.Console loaded via `Add-Type` from bundled DLLs in `LastWarAutoScreenshot/lib/`
- **Bridge pattern:** A thin C# wrapper class `ConsoleAppBridge.cs` in `LastWarAutoScreenshot/src/` exposes PowerShell-friendly static methods over Spectre.Console's fluent API, consistent with the existing `MouseControlAPI.cs` / `WindowEnumerationAPI.cs` pattern
- **Testability:** Every screen function accepts a `$Console` parameter typed `[Spectre.Console.IAnsiConsole]`; tests inject `[Spectre.Console.Testing.TestConsole]::new()` and assert on `$testConsole.Output`
- **Entry point:** `Start-LastWarAutoScreenshot` (public, exported) — the single function users call to launch the app
- **Folder layout:** All screen/page functions live in `Private/ConsoleApp/`; tests in `Tests/ConsoleApp/`
- **Macro storage:** `Private/Macros/yyyyMMdd_HHmmss_<name>.json` — one file per macro; Phase 3 only checks existence; Phase 4 defines the format
- **DLL versioning:** Bundled at a specific version recorded in `lib/VERSIONS.txt`; never auto-updated
- **Config validation:** Per-key validation rules co-located with defaults in `Get-DefaultModuleSettings.ps1`; a new `$script:ConfigValidationSchema` hashtable is added alongside the existing defaults object

### Phase 3 scope (what is and is not included)

**Included:** Main menu, window selection screen, configuration screens (Logging, MouseControl, EmergencyStop), storage info screen, startup config validation, `IAnsiConsole` injection throughout, full Pester test coverage using `TestConsole`.

**Explicitly out of scope for Phase 3:** Task Scheduler (Phase 5), visual screenshot region selection (Phase 6), live mouse coordinate display during recording (Phase 4).

---

1. [x] Acquire, bundle and load `Spectre.Console` DLLs
   1. [x] 1.1: Create `LastWarAutoScreenshot/lib/` folder
      - Download `Spectre.Console` NuGet package at the latest stable version using:

        ```powershell
        # One-time command to extract the DLL (does not require dotnet SDK, only nuget.exe or Invoke-WebRequest)
        Invoke-WebRequest "https://www.nuget.org/api/v2/package/Spectre.Console/<version>" -OutFile spectre.nupkg
        # Rename to .zip, extract, copy net6.0/Spectre.Console.dll to LastWarAutoScreenshot/lib/
        ```

      - Copy `Spectre.Console.dll` to `LastWarAutoScreenshot/lib/Spectre.Console.dll`
      - Repeat for `Spectre.Console.Testing` NuGet package; copy `Spectre.Console.Testing.dll` to `LastWarAutoScreenshot/lib/test/Spectre.Console.Testing.dll`
      - Create `LastWarAutoScreenshot/lib/VERSIONS.txt` with content:

        ```
        Spectre.Console=<exact version bundled>
        Spectre.Console.Testing=<exact version bundled>
        ```

        Record the exact version strings here in the plan once known
      - Add `LastWarAutoScreenshot/lib/**/*.dll` to `.gitattributes` with `binary` attribute so git does not diff the DLLs
      - Do NOT add them to `.gitignore` — they must be committed and shipped with the module
   2. [x] 1.2: Create `LastWarAutoScreenshot/src/ConsoleAppBridge.cs`
      - Namespace `LastWarAutoScreenshot`, class `ConsoleAppBridge`
      - References `Spectre.Console.dll`; must be compiled via `Add-Type -Path ... -ReferencedAssemblies`
      - Purpose: expose clean, PowerShell-callable static factory/helper methods that hide Spectre.Console's fluent/generic API from PowerShell callers; keeps PS code readable
      - Initial methods to include (others added per screen as needed):
        - `static IAnsiConsole CreateConsole()` — returns `AnsiConsole.Console` (the real live console)
        - `static SelectionPrompt<string> CreateSelectionPrompt(string title, string[] choices)` — creates a standard prompt ready to call `.Show(console)`
        - `static Table CreateTable(string[] columns)` — creates a `Table` with standard border style used project-wide
        - `static Panel CreatePanel(string content, string header)` — creates a `Panel` with standard styling
      - `SetLastError = false` — no P/Invoke in this file; it is pure managed .NET
      - Full XML doc comments on all public methods
   3. [x] 1.3: Update `LastWarAutoScreenshot.psm1`
      - Add `$spectreConsolePath = "$PSScriptRoot\lib\Spectre.Console.dll"` alongside the existing source path variables
      - Add `$consoleAppBridgePath = "$PSScriptRoot\src\ConsoleAppBridge.cs"` alongside the existing source path variables
      - Add both to the existing `$missingFiles` check loop (fatal if absent)
      - Add `'LastWarAutoScreenshot.ConsoleAppBridge'` to the `$typeNames` guard array
      - Load `Spectre.Console.dll` first (before compiling `ConsoleAppBridge.cs`) using `Add-Type -Path $spectreConsolePath`
      - Compile `ConsoleAppBridge.cs` using `Add-Type -Path $consoleAppBridgePath -ReferencedAssemblies $spectreConsolePath`
      - Dot-source all `Private/ConsoleApp/*.ps1` files in the existing private dot-sourcing loop (the loop already covers `Private/` — ensure it uses `-Recurse` so the subfolder is picked up automatically, or add an explicit `Get-ChildItem` call for the subfolder if `-Recurse` causes ordering issues)
   4. [x] 1.4: Create `LastWarAutoScreenshot/Tests/ConsoleApp/` folder
      - Add a `README.md` placeholder noting this folder holds all Phase 3 tests; to be populated per screen
   5. [x] 1.5: Verify the module loads cleanly after steps 1.1–1.4
      - Run: `Import-Module .\LastWarAutoScreenshot\LastWarAutoScreenshot.psd1 -Force -Verbose`
      - Confirm `[LastWarAutoScreenshot.ConsoleAppBridge]` type is accessible with no errors
      - Confirm `[Spectre.Console.AnsiConsole]` type is accessible
      - Confirm existing tests still pass (run full Pester suite; count must meet or exceed previous baseline)
   6. [x] 1.6: Create `LastWarAutoScreenshot/Tests/ConsoleApp/ConsoleAppBridge.Tests.ps1`
      - `[LastWarAutoScreenshot.ConsoleAppBridge]` type loads without error
      - `CreateConsole()` returns a non-null object
      - `CreateSelectionPrompt(title, choices)` returns a non-null object with `.Title` equal to the supplied title
      - `CreateTable(columns)` returns a non-null `Table`-typed object
      - `CreatePanel(content, header)` returns a non-null `Panel`-typed object
      - Run full Pester suite; confirm count increases

2. [x] Add config validation schema to `Get-DefaultModuleSettings.ps1`
   1. [x] 2.1: Define the validation schema structure
      - Add a `$script:ConfigValidationSchema` hashtable to `Get-DefaultModuleSettings.ps1` alongside the existing `Get-DefaultModuleSettings` function (not inside of it — module-scoped constant)
      - Schema format — each entry is keyed by `"Section.Key"` and contains:

        ```powershell
        @{
            Type         = 'int'                      # 'int', 'double', 'bool', 'string', 'intArray', 'stringEnum'
            Min          = 1                           # optional; numeric lower bound (inclusive)
            Max          = 1000                        # optional; numeric upper bound (inclusive)
            AllowedValues = @('File', 'EventLog', 'File,EventLog')  # optional; for stringEnum
            Description  = 'Human-readable description shown in the config screen'
            Nullable     = $false                      # whether $null is a valid value
        }
        ```

      - Populate entries for all keys in `Logging`, `MouseControl`, and `EmergencyStop` sections (every key that a user can change via the config screen)
      - Example entries to include:
        - `'Logging.MinimumLogLevel'` — `stringEnum`; `AllowedValues = @('Verbose','Info','Warning','Error')`
        - `'Logging.Backend'` — `stringEnum`; `AllowedValues = @('File','EventLog','File,EventLog')`
        - `'Logging.FileBackend.MaxSizeMB'` — `int`; `Min = 1`, `Max = 10240`
        - `'Logging.FileBackend.MaxFileCount'` — `int`; `Min = 1`, `Max = 10000`
        - `'Logging.FileBackend.MaxAgeDays'` — `int`; `Min = 1`, `Max = 3650`
        - `'Logging.FileBackend.RetentionFileCount'` — `int`; `Min = 1`, `Max = 100000`
        - `'MouseControl.OvershootFactor'` — `double`; `Min = 0.0`, `Max = 1.0`
        - `'MouseControl.MicroPauseChance'` — `double`; `Min = 0.0`, `Max = 1.0`
        - `'MouseControl.JitterRadiusPx'` — `int`; `Min = 0`, `Max = 20`
        - `'MouseControl.BezierControlPointOffsetFactor'` — `double`; `Min = 0.0`, `Max = 2.0`
        - `'MouseControl.MovementDurationRangeMs'` — `intArray`; both elements `Min = 0`, `Max = 5000`; element[0] must be ≤ element[1]
        - `'MouseControl.ClickDownDurationRangeMs'` — `intArray`; same constraints as above
        - `'MouseControl.ClickPreDelayRangeMs'` — `intArray`; same
        - `'MouseControl.ClickPostDelayRangeMs'` — `intArray`; same
        - `'MouseControl.MicroPauseDurationRangeMs'` — `intArray`; same
        - `'MouseControl.PathPointCount'` — `int`; `Min = 5`, `Max = 200`
        - `'EmergencyStop.PollIntervalMs'` — `int`; `Min = 10`, `Max = 5000`
        - `'EmergencyStop.MouseGestureHoldDurationMs'` — `int`; `Min = 500`, `Max = 30000`
        - `'EmergencyStop.AutoStart'` — `bool`
        - `'EmergencyStop.MouseGestureEnabled'` — `bool`
        - `'MouseControl.EasingEnabled'`, `'MouseControl.OvershootEnabled'`, `'MouseControl.MicroPausesEnabled'`, `'MouseControl.JitterEnabled'` — all `bool`
   2. [x] 2.2: Create `Test-ConfigValue` (private) in `Private/ConsoleApp/ConfigValidation.ps1`
      - `Test-ConfigValue -Key [string] -Value [object]`
      - Looks up `$script:ConfigValidationSchema[$Key]` — returns `[PSCustomObject]@{Valid=$true; Message=''}` if key not in schema (unknown keys pass through silently)
      - Validates `Type`, `Min`/`Max` (for numerics and each element of intArray), `AllowedValues` (case-insensitive for stringEnum), `Nullable`
      - For `intArray`: validates element count is exactly 2 and element[0] ≤ element[1]
      - Returns `[PSCustomObject]@{Valid=[bool]; Message=[string]}` — `Message` is the human-readable error shown in the config screen when `Valid = $false`
      - Pure PowerShell; no `Add-Type`; fully testable
   3. [x] 2.3: Create `LastWarAutoScreenshot/Tests/ConsoleApp/ConfigValidation.Tests.ps1`
      - `Test-ConfigValue`: valid int within range → `Valid=$true`; int below Min → `Valid=$false` with non-empty message; int above Max → same; stringEnum valid value → `Valid=$true`; invalid value → `Valid=$false`; bool true → `Valid=$true`; intArray with element[0] > element[1] → `Valid=$false`; unknown key not in schema → `Valid=$true`
      - Run full Pester suite; confirm count increases

3. [x] Create the entry point and main menu screen
   1. [x] 3.1: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-MainMenu.ps1`
      - `Show-MainMenu -Console [Spectre.Console.IAnsiConsole]`
      - Displays a `SelectionPrompt` with the following options:
        - `Select target window`
        - `Configure module`
        - `Record macro` (stub — displays "Not yet available" panel when chosen; returns to main menu)
        - `Run macro` — greyed out (disabled choice text, different Spectre.Console style) when no `*.json` files exist in the module's `Macros/` folder; shows `SelectionPrompt` of macro filenames (parsed from `yyyyMMdd_HHmmss_<name>.json` filenames) when macros do exist
        - `Exit`
      - To detect macros: check `Join-Path $script:ModuleRootPath 'Private\Macros\*.json'` using `Get-ChildItem`; if count is 0 the option is rendered as `[grey](No macros recorded)[/]` and is excluded from selectable choices
      - Returns a string matching one of the menu option identifiers: `'SelectWindow'`, `'Configure'`, `'RecordMacro'`, `'RunMacro'`, `'Exit'`
      - Full comment-based help
   2. [x] 3.2: Create `LastWarAutoScreenshot/Public/Start-LastWarAutoScreenshot.ps1`
      - `[CmdletBinding()]` — no mandatory parameters
      - Optional `[Spectre.Console.IAnsiConsole]$Console` parameter defaulting to `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`; this is the testability injection point
      - On startup:
        1. Validates the config file via `Invoke-StartupConfigValidation` (step 3.3) — displays any errors/warnings as a Spectre.Console `Panel` with red/yellow markup before the main menu appears; does not abort, user must acknowledge with Enter
        2. Enters an infinite `while ($true)` loop calling `Show-MainMenu -Console $Console`
        3. Dispatches on the returned menu option string via `switch`
        4. `'Exit'` breaks the loop
        5. All other options call the relevant screen function (steps 4, 5, 6) passing `$Console`
      - Full comment-based help with `.NOTES` documenting the `$Console` injection pattern
   3. [x] 3.3: Create `LastWarAutoScreenshot/Private/ConsoleApp/Invoke-StartupConfigValidation.ps1`
      - `Invoke-StartupConfigValidation -Console [Spectre.Console.IAnsiConsole]`
      - Calls `Get-ModuleConfiguration`; if the file does not exist or is empty (both handled by `Get-ModuleConfiguration`'s own defaults path) the function returns immediately with no warnings — a freshly-created default config is always valid
      - If the file exists but contains invalid JSON: displays an error panel `"Configuration file contains invalid JSON. Default values will be used. Please reconfigure via Configure Module."` via `$Console.Write()`
      - If the file exists and is valid JSON: calls `Test-ConfigValue` for every key in `$script:ConfigValidationSchema`; collects all failures; if any exist, displays a warning panel listing each failing key and the validation message; user presses Enter to continue
      - Logs any discovered issues via `Write-LastWarLog -Level Warning`
      - Does NOT abort startup; only informs the user
      - Returns `[PSCustomObject]@{HasErrors=[bool]; Messages=[string[]]}`
      - Full comment-based help
   4. [x] 3.4: Update `LastWarAutoScreenshot.psd1`
      - Add `'Start-LastWarAutoScreenshot'` to `FunctionsToExport`
   5. [x] 3.5: Update `LastWarAutoScreenshot.psm1`
      - Add `Export-ModuleMember -Function 'Start-LastWarAutoScreenshot'` alongside the existing exports
   6. [x] 3.6: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-MainMenu.Tests.ps1`
      - Import module; all tests use `InModuleScope`
      - Setup: `$testConsole = [Spectre.Console.Testing.TestConsole]::new()`; load `Spectre.Console.Testing.dll` via `Add-Type` in `BeforeAll`
      - Mock `Get-ChildItem` returning empty list → "Run macro" option rendered, is not in selectable choices (assert `$testConsole.Output` does not contain a selectable "Run macro" choice); queue `testConsole.Input.PushTextWithEnter('Exit')` to break prompt
      - Mock `Get-ChildItem` returning one mock file `'20260101_120000_TestMacro.json'` → "Run macro" choice is present in output
      - Return value from `Show-MainMenu` matches expected identifier string for each choice
   7. [x] 3.7: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Start-LastWarAutoScreenshot.Tests.ps1`
      - Mock `Show-MainMenu` returning `'Exit'` → loop exits cleanly, no exception
      - Mock `Invoke-StartupConfigValidation` returning `@{HasErrors=$false; Messages=@()}` → no error panel rendered; assert `$testConsole.Output` does not contain error markup
      - Mock `Invoke-StartupConfigValidation` returning `@{HasErrors=$true; Messages=@('Logging.MinimumLogLevel: invalid value')}` → error panel content appears in `$testConsole.Output`
      - Mock `Show-MainMenu` returning `'SelectWindow'` once, then `'Exit'` → window selection screen function called exactly once
      - `$Console` defaulting to real console when not provided — verify the parameter default is `[LastWarAutoScreenshot.ConsoleAppBridge]::CreateConsole()`
   8. [x] 3.8: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Invoke-StartupConfigValidation.Tests.ps1`
      - Config file does not exist → `Get-ModuleConfiguration` creates defaults; function returns `HasErrors=$false`; no output written to `$testConsole`
      - Config file exists, all values valid → returns `HasErrors=$false`; no panel written
      - Config file exists, one invalid value → returns `HasErrors=$true`; `$testConsole.Output` contains the key name and validation message
      - Multiple invalid values → all listed in output
      - Invalid JSON in config file → error panel shown; `Write-LastWarLog` called with `Level = 'Warning'`
   9. [x] 3.9: Run full Pester suite; confirm count increases and all tests pass

4. [x] Implement the window selection screen
   1. [x] 4.1: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-WindowSelectionScreen.ps1`
      - `Show-WindowSelectionScreen -Console [Spectre.Console.IAnsiConsole]`
      - **Step 1 — Sort/filter selection:**
        - Display a `SelectionPrompt` "Sort windows by:" with choices: `'Process name (A–Z)'`, `'Process name (Z–A)'`, `'Window title (A–Z)'`, `'Window title (Z–A)'`, `'Minimised first'`, `'Minimised last'`
        - Map choice to a sort expression used in step 2
      - **Step 2 — Enumerate and display windows:**
        - Call `Get-EnumeratedWindows` (with no filters — same behaviour as current `Select-TargetWindowFromMenu` with no parameters)
        - If result is empty: display error `Panel` `"No windows found. Ensure at least one application is open and try again."` using red markup; log via `Write-LastWarLog -Level Error`; return `$null`
        - Sort the results using the sort expression from step 1
        - Build a Spectre.Console `Table` with columns: `#`, `Active`, `Process`, `Application`, `Minimised`; populate with window data; mark the active (foreground) window with `[bold]*[/]` in the Active column
        - Write the table to `$Console`
      - **Step 3 — Window selection:**
        - Build a `SelectionPrompt` from the sorted window list; display format per choice: `"<#>: <ProcessName> — <WindowTitle> (<WindowState>)"`; add `"[Back to main menu]"` as the last choice
        - Show the prompt; if user chooses `"[Back to main menu]"` return `$null`
        - Get selected window object by correlating the numbered choice back to the sorted list
      - **Step 4 — Validate window still exists:**
        - Call `Test-WindowHandleValid` (existing private function); if window is closed display error panel `"The selected window has closed. Please select another."`, log Error, re-display step 2 (loop back — do not return to main menu)
      - **Step 5 — Save and return:**
        - Call `Save-ModuleConfiguration` to persist the selected window
        - Display success panel `"Window '[bold]<WindowTitle>[/]' selected and saved to configuration."`
        - Return the selected window object
      - Full comment-based help; all error paths log via `Write-LastWarLog`
   2. [x] 4.2: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-WindowSelectionScreen.Tests.ps1`
      - Mock `Get-EnumeratedWindows` returning empty list → error panel shown; `$testConsole.Output` contains "No windows found"; `Write-LastWarLog` called with `Level = 'Error'`; returns `$null`
      - Mock `Get-EnumeratedWindows` returning two mock windows → table and selection prompt rendered; `$testConsole.Output` contains both window titles
      - Queue input selecting `"[Back to main menu]"` → returns `$null`
      - Queue input selecting a valid window → `Save-ModuleConfiguration` called; returns selected window object
      - Mock `Test-WindowHandleValid` returning `$false` → error panel shown; mock `Test-WindowHandleValid` is called again after user re-selects (loop test — use a counter mock that returns `$false` once, then `$true`)
      - Sort selection propagated: mock `Get-EnumeratedWindows`; verify the table rows in `$testConsole.Output` appear in the expected sorted order
      - Run full Pester suite; confirm count increases

5. [x] Implement the configuration screens
   1. [x] 5.1: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-ConfigMenuScreen.ps1`
      - `Show-ConfigMenuScreen -Console [Spectre.Console.IAnsiConsole]`
      - Displays a `SelectionPrompt` "Configuration area:" with choices:
        - `Logging settings`
        - `Mouse control settings`
        - `Emergency stop settings`
        - `Storage & log file info`
        - `[Back to main menu]`
      - Loops until user selects `"[Back to main menu]"`; dispatches each choice to the appropriate config sub-screen (steps 5.2–5.4, 6)
      - Passes `$Console` to all sub-screens
      - Full comment-based help
   2. [x] 5.2: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-LoggingConfigScreen.ps1`
      - `Show-LoggingConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Loads current config via `Get-ModuleConfiguration`
      - Displays a `Table` showing current values for all `Logging.*` and `Logging.FileBackend.*` keys, their current values, allowed values / range, and a description sourced from `$script:ConfigValidationSchema`
      - For each key in turn (via a `TextPrompt` loop):
        - Prompt: `"<Description> [current: <value>] (<constraints>). Press Enter to keep current:"`
        - If the user enters an empty string (just presses Enter), keep the existing value
        - If the user types a value, call `Test-ConfigValue`; if invalid, display the error message in red and re-prompt the same key (do not advance to the next key until valid input is given or user accepts the current value)
        - Offer `"[Reset to default]"` as a recognised input string that substitutes the default value from `Get-DefaultModuleSettings`
      - After all keys: display a `SelectionPrompt` `"Save changes?"` with choices `'Yes — save now'`, `'Reset ALL Logging settings to defaults'`, `'Discard changes'`
      - `'Yes — save now'`: call `Save-ModuleConfiguration` with updated config; display success panel; log Info
      - `'Reset ALL Logging settings to defaults'`: replace all Logging keys with defaults from `Get-DefaultModuleSettings`; save; display success panel; log Info
      - `'Discard changes'`: return without saving; display info panel `"No changes saved."`
      - Full comment-based help; all error paths logged
   3. [ ] 5.3: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-MouseControlConfigScreen.ps1`
      - `Show-MouseControlConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Identical pattern to `Show-LoggingConfigScreen` but for all `MouseControl.*` keys
      - For `bool` keys (`EasingEnabled`, `OvershootEnabled`, `MicroPausesEnabled`, `JitterEnabled`): use `ConfirmationPrompt` (yes/no) instead of `TextPrompt`
      - For `intArray` keys (range pairs): prompt for min and max separately; label as `"<Key> minimum (ms):"` and `"<Key> maximum (ms):"` respectively; after both are entered, validate the pair as a unit via `Test-ConfigValue`
      - Save/reset/discard options identical to `Show-LoggingConfigScreen`
      - Full comment-based help; all error paths logged
   4. [ ] 5.4: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-EmergencyStopConfigScreen.ps1`
      - `Show-EmergencyStopConfigScreen -Console [Spectre.Console.IAnsiConsole]`
      - Identical pattern to `Show-LoggingConfigScreen` but for all `EmergencyStop.*` keys
      - For `HotkeyVKeyCodes` (int array of variable length): display as comma-separated hex strings (e.g. `0x11, 0x10, 0xDC`); accept input as comma-separated hex or decimal integers; parse and validate each element is a valid VKey code (0x01–0xFE); display informational note: `"Note: '#' key is 0xDC on UK layouts and layout-dependent on others. See README for details."`
      - Save/reset/discard options identical above
      - Full comment-based help; all error paths logged
   5. [x] 5.5: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-ConfigMenuScreen.Tests.ps1`
      - Queue `"[Back to main menu]"` → loop exits; no sub-screen called
      - Queue `"Logging settings"` then `"[Back to main menu]"` → `Show-LoggingConfigScreen` called exactly once
      - Repeat for each sub-screen option
      - Run full Pester suite; confirm count increases
   6. [x] 5.6: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-LoggingConfigScreen.Tests.ps1`
      - Mock `Get-ModuleConfiguration` returning a known config; mock `Save-ModuleConfiguration`
      - Queue empty string for all prompts → all current values retained; `Save-ModuleConfiguration` called with unchanged config when user chooses `'Yes — save now'`
      - Queue an invalid value for `MinimumLogLevel` → error message appears in `$testConsole.Output`; prompt is repeated
      - Queue `'[Reset to default]'` for one key → that key's value in the saved config equals the default from `Get-DefaultModuleSettings`
      - Queue `'Reset ALL Logging settings to defaults'` at save prompt → all Logging keys in saved config equal defaults
      - Queue `'Discard changes'` → `Save-ModuleConfiguration` NOT called
      - Run full Pester suite; confirm count increases
   7. [ ] 5.7: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-MouseControlConfigScreen.Tests.ps1`
      - Same pattern as 5.6 but for `MouseControl.*` keys
      - Bool key: queue `'n'` for an enabled bool key → value saved as `$false`
      - intArray: queue min > max → error message appears; pair is not saved; re-prompt
      - Queue valid min and max in order → saved as `@(min, max)` array
      - Run full Pester suite; confirm count increases
   8. [ ] 5.8: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-EmergencyStopConfigScreen.Tests.ps1`
      - Same pattern as 5.6 but for `EmergencyStop.*` keys
      - `HotkeyVKeyCodes`: queue `'0x11, 0x10, 0xDC'` → saved as `@(17, 16, 220)`
      - Queue `'0xFF, 0x200'` (second value out of range) → error; re-prompt
      - Informational note about `#` key layout appears in `$testConsole.Output`
      - Run full Pester suite; confirm count increases

6. [ ] Implement the storage & log file info screen
   1. [ ] 6.1: Add a `Screenshots` section to `ModuleConfig.json` and defaults
      - New key: `"Screenshots": { "StoragePath": "", "MaxStorageGB": 2.0 }`
      - `StoragePath` default: `""` (empty string = not yet configured; storage screen shows "Not configured")
      - `MaxStorageGB` default: `2.0`; validation: `double`, `Min = 0.1`, `Max = 2048.0`
      - Add entries to `$script:ConfigValidationSchema` for `'Screenshots.StoragePath'` (string, nullable = true) and `'Screenshots.MaxStorageGB'` (double, Min = 0.1, Max = 2048.0)
      - Update `Get-DefaultModuleSettings` to include `Screenshots` section
      - Update `Get-ModuleConfiguration` to inject missing `Screenshots` keys using the same `Add-Member` pattern as existing sections
      - Update `Save-ModuleConfiguration` to persist `Screenshots` keys
      - Update `ModuleConfiguration.Tests.ps1`: add round-trip tests for `Screenshots.StoragePath` and `Screenshots.MaxStorageGB`; add default-injection test
   2. [ ] 6.2: Create `LastWarAutoScreenshot/Private/ConsoleApp/Get-StorageInfo.ps1`
      - `Get-StorageInfo`
      - Reads `Screenshots.StoragePath` and `Screenshots.MaxStorageGB` from config
      - If `StoragePath` is empty or path does not exist: returns `[PSCustomObject]@{IsConfigured=$false; UsedGB=0.0; MaxGB=0.0; UsedPercent=0.0; LogFileSizeGB=0.0}`
      - If configured: sums `(Get-ChildItem -Path $StoragePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum` for screenshot files; converts to GB
      - Also computes log file folder size using `Logging.FileBackend` path (module root by convention)
      - Returns `[PSCustomObject]@{IsConfigured=[bool]; UsedGB=[double]; MaxGB=[double]; UsedPercent=[double]; LogFileSizeGB=[double]}`
      - Error handling: if path exists but access is denied, returns `IsConfigured=$false`; logs Error
      - Pure PowerShell; no `Add-Type`
   3. [ ] 6.3: Create `LastWarAutoScreenshot/Private/ConsoleApp/Show-StorageInfoScreen.ps1`
      - `Show-StorageInfoScreen -Console [Spectre.Console.IAnsiConsole]`
      - Calls `Get-StorageInfo`
      - If not configured: display info panel `"Screenshot storage path is not yet configured. Set it in the Screenshots section below."`  then prompts for `StoragePath` and `MaxStorageGB` using `TextPrompt` with `Test-ConfigValue` validation (same save/discard pattern as config screens)
      - If configured: display a Spectre.Console `BreakdownChart` (or `BarChart` if `BreakdownChart` is unavailable in the bundled version) showing used vs free storage as a percentage; display current values as a `Table` (Used GB, Max GB, % used, Log files GB); display current config values for `MaxStorageGB` with option to update them
      - If `UsedPercent >= 90`: display warning panel `"Screenshot storage is over 90% full. Consider increasing the limit or clearing old screenshots."` in yellow
      - Save/discard pattern identical to config screens
      - Full comment-based help; all error paths logged
   4. [ ] 6.4: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Get-StorageInfo.Tests.ps1`
      - Mock `Get-ModuleConfiguration` returning `StoragePath = ''` → returns `IsConfigured=$false`
      - Mock `Get-ModuleConfiguration` returning a valid path that does not exist → returns `IsConfigured=$false`
      - Mock `Get-ChildItem` returning a fixed list of files with known sizes → `UsedGB` calculated correctly; `UsedPercent` calculated correctly against `MaxStorageGB`
      - Access denied path → returns `IsConfigured=$false`; `Write-LastWarLog` called with `Level = 'Error'`
      - Run full Pester suite; confirm count increases
   5. [ ] 6.5: Create `LastWarAutoScreenshot/Tests/ConsoleApp/Show-StorageInfoScreen.Tests.ps1`
      - Mock `Get-StorageInfo` returning `IsConfigured=$false` → info panel shown; prompts for `StoragePath` and `MaxStorageGB`
      - Mock `Get-StorageInfo` returning `UsedPercent = 95.0` → warning panel content appears in `$testConsole.Output`
      - Mock `Get-StorageInfo` returning `UsedPercent = 50.0` → no warning panel
      - Queue valid values for storage prompts → `Save-ModuleConfiguration` called with correct values
      - Queue invalid `MaxStorageGB` (e.g. `-1`) → error shown; re-prompt
      - Run full Pester suite; confirm count increases

7. [ ] Run full Pester suite and validate
   1. [ ] 7.1: Run the complete, unfiltered Pester suite (all files, no tag filters)
      - Record total test count; it must meet or exceed the Phase 2 final baseline
      - All tests must pass with 0 failures
      - If any test fails that previously passed, halt and investigate; do not proceed
   2. [ ] 7.2: Manually smoke-test `Start-LastWarAutoScreenshot` in a real terminal
      - Import module; call `Start-LastWarAutoScreenshot`
      - Navigate every screen at least once; exercise sort options in window selection; save and reload a config change; observe the storage screen
      - Confirm no ANSI artefacts or rendering glitches
   3. [ ] 7.3: Update `LastWarAutoScreenshot/Docs/README.md`
      - Add "Getting Started" section documenting `Start-LastWarAutoScreenshot` as the entry point with a usage example
      - Document the `Private/Macros/` folder naming convention for macros
      - Document the `lib/VERSIONS.txt` file and how to update the bundled DLLs if needed
      - Document all new config keys (`Screenshots.StoragePath`, `Screenshots.MaxStorageGB`) with types, defaults, and examples
      - Document the `IAnsiConsole` injection pattern for contributors writing new screens

## Phase 4: Mouse Macro Recording

1. [ ] Implement action recording macro that generates user settings in module configuration (JSON import/export supported)
   - Prompt user to start recording
   - Display recording status
   - Use keyboard to select what to record
     - A target box/circle
     - A drag-click
     - A screenshot region
   - For recording move mouse, click on target region
     - Prompt user to move mouse to centre of region to click and press configurable keyboard shortcut Ctrl-Shift-R
     - Prompt user to move mouse to top left position of region to click and press Ctrl-Shift-R
     - If possible display a box border outline over the window and allow user to accept or redo
   - For recording click drag
     - Prompt user to move mouse to centre of region to start click drag and press configurable keyboard shorcut Ctrl-Shift-R
     - Prompt user to drag-click to destination - record start and end point of drag
   - After each action has been recorded with Ctrl-Shift-R prompt user to press Y to commit action, R to redo, Q to quit back to main menu

## Phase 5: Configuration & Scheduling

1. [ ] Design and implement configuration schema supporting both JSON and YAML formats:

- Note: Most, if not all of this task has already been done
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

## Phase 6: Screenshot Management

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

## Phase 7: Module Installation & Versioning

1. [ ] Implement PowerShell v7 best practices for module installation:

- Support installation to user and system module paths
- Proper module manifest (psd1) with metadata
- Exported functions defined in manifest (as developed)
- Semantic versioning for module releases

1. [ ] Create installation documentation and example commands

## Phase 8: Documentation & Examples

1. [ ] Create example configuration files with inline comments
2. [ ] Document window-relative coordinate system
3. [ ] Provide quick start guide with simple working example
4. [ ] Document all exported PowerShell functions as they are created

## Phase 9: Azure Integration (Future)

1. [ ] Prepare for future Azure Blob upload integration:

- Design extensible screenshot saving logic
- SAS token-based authentication
- Exponential backoff with jitter for upload retry logic
- Configurable retry attempts
- Upload failure handling with same retry logic as other operations
