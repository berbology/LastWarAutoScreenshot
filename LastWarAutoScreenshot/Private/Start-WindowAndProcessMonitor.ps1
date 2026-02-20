
function Prompt-RetryAbort {
    param($prompt)
    $choice = $null
    while ($null -eq $choice) {
        $choice = Read-Host $prompt
        if ($choice -eq 'R' -or $choice -eq 'r') {
            return 'Retry'
        } elseif ($choice -eq 'A' -or $choice -eq 'a') {
            return 'Abort'
        } else {
            Write-Host "Invalid input. Please enter R or A."
            $choice = $null
        }
    }
}

<#
.SYNOPSIS
    Executes a single poll cycle checking whether the monitored window and process are still alive.

.DESCRIPTION
    Called by the System.Timers.Timer Elapsed handler in Start-WindowAndProcessMonitor on each
    poll interval. Checks window validity and process exit state. On detection, stops the timer,
    prompts the user to retry or abort, and acts accordingly. Extracted from the timer callback
    to allow synchronous unit testing with Pester mocks, which cannot intercept code running on
    .NET ThreadPool threads.

.NOTES
    Win32 event hooks (SetWinEventHook / WinEventProc) were considered as an alternative to
    polling but rejected for two reasons:

    1. Testability: Hook callbacks are invoked on .NET thread-pool threads. Pester mocks are
       scoped to the calling runspace and are not visible on thread-pool threads, making any
       code that relies on hook callbacks effectively untestable with Pester.

    2. Complexity: Registering, marshalling, and unregistering unmanaged WinEvent hooks from
       PowerShell requires unsafe delegates and manual lifetime management, adding significant
       complexity for no functional benefit over polling at the intervals used here.

    Polling via System.Timers.Timer is simple, fully testable, and sufficient for the
    detection latency requirements of this module.

.PARAMETER State
    Hashtable containing shared monitor state with the following keys: Stopped, Timer,
    WindowHandle, ProcessId, PollIntervalMs, OnClosedOrExited, CallbackState, ProcessObject,
    IsWindowFn, IsWindowVisibleFn, and IsIconicFn.

.NOTES
    This is a private function not exported from the module.
#>
function Invoke-MonitorPoll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State
    )

    if ($State.Stopped) { return }

    $splatParams = @{ WindowHandle = $State.WindowHandle }
    if ($null -ne $State.IsWindowFn)        { $splatParams['IsWindowFn']        = $State.IsWindowFn }
    if ($null -ne $State.IsWindowVisibleFn) { $splatParams['IsWindowVisibleFn'] = $State.IsWindowVisibleFn }
    if ($null -ne $State.IsIconicFn)        { $splatParams['IsIconicFn']        = $State.IsIconicFn }

    $valid = $false
    try {
        $valid = Test-WindowHandleValid @splatParams
    } catch {
        $State.Stopped = $true
        if ($null -ne $State.Timer) { $State.Timer.Stop() }
        Write-LastWarLog -Message "Exception during window validity polling: $_" -Level Error -FunctionName 'Start-WindowAndProcessMonitor' -Context 'Polling' -LogStackTrace $_
        Write-Host "`e[31mERROR: Window monitoring exception detected. $(Get-LogCheckHint)`e[0m"
        $userChoice = Prompt-RetryAbort 'Window monitoring error detected. Retry monitoring (R) or Abort (A)? [R/A]'
        if ($userChoice -eq 'Retry') {
            Write-LastWarLog -Message 'User chose to retry after polling error.' -Level Info -FunctionName 'Start-WindowAndProcessMonitor' -Context 'UserPrompt'
            Start-WindowAndProcessMonitor -WindowHandle $State.WindowHandle -ProcessId $State.ProcessId -PollIntervalMs $State.PollIntervalMs -OnClosedOrExited $State.OnClosedOrExited -CallbackState $State.CallbackState | Out-Null
        } else {
            Write-LastWarLog -Message 'User chose to abort after polling error.' -Level Error -FunctionName 'Start-WindowAndProcessMonitor' -Context 'UserPrompt'
            try { & $State.OnClosedOrExited 'Error' $State.CallbackState } catch {}
        }
        return
    }

    if (-not $valid) {
        $State.Stopped = $true
        if ($null -ne $State.Timer) { $State.Timer.Stop() }
        Write-LastWarLog -Message 'Window closed detected.' -Level Error -FunctionName 'Start-WindowAndProcessMonitor' -Context 'Detection'
        Write-Host "`e[31mERROR: Window closed detected. $(Get-LogCheckHint)`e[0m"
        $userChoice = Prompt-RetryAbort 'Window closed. Retry monitoring (R) or Abort (A)? [R/A]'
        if ($userChoice -eq 'Retry') {
            Write-LastWarLog -Message 'User chose to retry after window closed.' -Level Info -FunctionName 'Start-WindowAndProcessMonitor' -Context 'UserPrompt'
            Start-WindowAndProcessMonitor -WindowHandle $State.WindowHandle -ProcessId $State.ProcessId -PollIntervalMs $State.PollIntervalMs -OnClosedOrExited $State.OnClosedOrExited -CallbackState $State.CallbackState | Out-Null
        } else {
            Write-LastWarLog -Message 'User chose to abort after window closed.' -Level Error -FunctionName 'Start-WindowAndProcessMonitor' -Context 'UserPrompt'
            try { & $State.OnClosedOrExited 'WindowClosed' $State.CallbackState } catch {}
        }
        return
    }

    if ($null -ne $State.ProcessObject) {
        $exited = $false
        try {
            $exited = $State.ProcessObject.HasExited
        } catch {
            $exited = $true
        }
        if ($exited) {
            $State.Stopped = $true
            if ($null -ne $State.Timer) { $State.Timer.Stop() }
            Write-LastWarLog -Message 'Process exited detected.' -Level Error -FunctionName 'Start-WindowAndProcessMonitor' -Context 'Detection'
            Write-Host "`e[31mERROR: Process exited detected. $(Get-LogCheckHint)`e[0m"
            $userChoice = Prompt-RetryAbort 'Process exited. Retry monitoring (R) or Abort (A)? [R/A]'
            if ($userChoice -eq 'Retry') {
                Write-LastWarLog -Message 'User chose to retry after process exited.' -Level Info -FunctionName 'Start-WindowAndProcessMonitor' -Context 'UserPrompt'
                Start-WindowAndProcessMonitor -WindowHandle $State.WindowHandle -ProcessId $State.ProcessId -PollIntervalMs $State.PollIntervalMs -OnClosedOrExited $State.OnClosedOrExited -CallbackState $State.CallbackState | Out-Null
            } else {
                Write-LastWarLog -Message 'User chose to abort after process exited.' -Level Error -FunctionName 'Start-WindowAndProcessMonitor' -Context 'UserPrompt'
                try { & $State.OnClosedOrExited 'ProcessExited' $State.CallbackState } catch {}
            }
        }
    }
}

<#
.SYNOPSIS
    Continuously monitors a window handle and process for closure or exit.

.DESCRIPTION
    Starts polling the window handle and process at a configurable interval. If the window
    closes or the process exits, prompts the user to retry or abort. On abort, invokes the
    OnClosedOrExited callback. On retry, restarts monitoring. Monitoring continues until
    stopped via the returned Stop scriptblock.

.PARAMETER WindowHandle
    The handle (IntPtr, int64, or string) of the window to monitor.

.PARAMETER ProcessId
    The process ID (int) to monitor.

.PARAMETER PollIntervalMs
    Polling interval in milliseconds (default: 1000).

.PARAMETER OnClosedOrExited
    ScriptBlock invoked when monitoring ends with abort. Receives reason ('WindowClosed',
    'ProcessExited', or 'Error') and CallbackState as arguments.

.PARAMETER CallbackState
    Optional state object passed as the second argument to OnClosedOrExited.

.PARAMETER IsWindowFn
    Optional ScriptBlock override for the window existence check. Defaults to Win32 IsWindow.

.PARAMETER IsWindowVisibleFn
    Optional ScriptBlock override for the window visibility check.

.PARAMETER IsIconicFn
    Optional ScriptBlock override for the minimised window check.

.OUTPUTS
    [PSCustomObject] with Timer, ProcessObject, Stop, and Cleanup scriptblock properties.

.NOTES
    Win32 event hooks (SetWinEventHook / WinEventProc) were considered as an alternative to
    polling but rejected for two reasons:

    1. Testability: Hook callbacks are invoked on .NET thread-pool threads. Pester mocks are
       scoped to the calling runspace and are not visible on thread-pool threads, making any
       code that relies on hook callbacks effectively untestable with Pester.

    2. Complexity: Registering, marshalling, and unregistering unmanaged WinEvent hooks from
       PowerShell requires unsafe delegates and manual lifetime management, adding significant
       complexity for no functional benefit over polling at the intervals used here.

    Polling via System.Timers.Timer is simple, fully testable, and sufficient for the
    detection latency requirements of this module.
    Documentation note: README.md coverage of this design decision is deferred to task 2.4.x.

.EXAMPLE
    $monitor = Start-WindowAndProcessMonitor -WindowHandle 123456 -ProcessId 12345 -OnClosedOrExited { Write-Host 'Monitoring ended.' }
    # ...later...
    & $monitor.Stop
    & $monitor.Cleanup
#>
function Start-WindowAndProcessMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$WindowHandle,
        [Parameter(Mandatory)]
        [int]$ProcessId,
        [int]$PollIntervalMs = 1000,
        [Parameter(Mandatory)]
        [ScriptBlock]$OnClosedOrExited,
        [Parameter()]
        $CallbackState = $null,
        [Parameter()]
        [ScriptBlock]$IsWindowFn = $null,
        [Parameter()]
        [ScriptBlock]$IsWindowVisibleFn = $null,
        [Parameter()]
        [ScriptBlock]$IsIconicFn = $null
    )

    try {
        $processObject = Get-MonitorProcess $ProcessId

        $state = @{
            Stopped           = $false
            Timer             = $null
            WindowHandle      = $WindowHandle
            ProcessId         = $ProcessId
            PollIntervalMs    = $PollIntervalMs
            OnClosedOrExited  = $OnClosedOrExited
            CallbackState     = $CallbackState
            ProcessObject     = $processObject
            IsWindowFn        = $IsWindowFn
            IsWindowVisibleFn = $IsWindowVisibleFn
            IsIconicFn        = $IsIconicFn
        }

        $timer = [System.Timers.Timer]::new($PollIntervalMs)
        $timer.AutoReset = $true
        $state.Timer = $timer

        $timer.add_Elapsed({
            try {
                Invoke-MonitorPoll -State $state
            } catch {
                # Ultimate safety net - DO NOT throw from event handler
            }
        }.GetNewClosure())

        $timer.Start()

        $cleanup = {
            try {
                $state.Timer.Stop()
            } catch {
                # Silently ignore timer stop errors
            }
            try {
                $state.Timer.Dispose()
            } catch {
                # Silently ignore timer dispose errors
            }
            if ($null -ne $state.ProcessObject) {
                try {
                    $state.ProcessObject.Dispose()
                } catch {
                    # Silently ignore process dispose errors
                }
            }
        }.GetNewClosure()

        return [PSCustomObject]@{
            Timer         = $timer
            ProcessObject = $processObject
            Stop          = { $state.Stopped = $true; $state.Timer.Stop() }.GetNewClosure()
            Cleanup       = $cleanup
        }
    } catch {
        return $null
    }
}
