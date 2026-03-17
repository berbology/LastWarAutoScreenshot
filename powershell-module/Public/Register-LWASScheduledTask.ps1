function Invoke-NewScheduledTaskSettingsSet {
    param(
        [Parameter(Mandatory)]
        [timespan]$ExecutionTimeLimit,
        [bool]$StopIfGoingOnBatteries = $true,
        [bool]$StartWhenAvailable = $false
    )
    $settingsArgs = @{ ExecutionTimeLimit = $ExecutionTimeLimit }
    if ($StopIfGoingOnBatteries) {
        $settingsArgs['StopIfGoingOnBatteries'] = $true
    } else {
        $settingsArgs['DontStopIfGoingOnBatteries'] = $true
    }
    if ($StartWhenAvailable) {
        $settingsArgs['StartWhenAvailable'] = $true
    }
    New-ScheduledTaskSettingsSet @settingsArgs
}

function Invoke-RegisterScheduledTask {
    param(
        [Parameter(Mandatory)]
        [string]$TaskName,
        $Action,
        $Trigger,
        $Settings,
        [string]$RunLevel = 'Limited',
        [switch]$Force
    )
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
        -Settings $Settings -RunLevel $RunLevel -Force:$Force
}

function Register-LWASScheduledTask {
    <#
    .SYNOPSIS
        Registers a Windows Scheduled Task that runs a LWAS macro against a target process.

    .DESCRIPTION
        Validates that the specified macro exists, generates a launcher script, then registers
        a Windows Scheduled Task that runs pwsh.exe with that launcher on the given schedule.

        The task name is 'LWAS_<MacroName>' and runs as the current user at the Limited
        privilege level (non-elevated). Tasks only run when the user is logged on, as window
        interaction requires the interactive user session.

        Supports -WhatIf and -Confirm via ShouldProcess.

    .PARAMETER MacroName
        The name of the macro to run. Must exist (validated via Get-LWASMacro). If not found,
        the function throws before any task registration occurs.

    .PARAMETER ProcessName
        The target process name (e.g. 'lastwar.exe') passed to Get-LWASTargetWindow in the
        generated launcher script.

    .PARAMETER StartAt
        The date and time of the first task trigger. Can be a [datetime] object or a string
        parseable as a datetime (e.g. '2026-04-01 08:00', [datetime]::Now.AddMinutes(5)).
        If the specified time is in the past, Windows Task Scheduler will fire the task
        immediately upon registration.

    .PARAMETER RepeatEvery
        A [TimeSpan] value controlling how often the task repeats after the initial trigger.
        When omitted, the task runs once at StartAt with no repetition. Common patterns:
        - [TimeSpan]::FromMinutes(5)  → runs every 5 minutes
        - [TimeSpan]::FromHours(1)     → runs every 1 hour
        - [TimeSpan]::FromHours(4)     → runs every 4 hours
        - [TimeSpan]::FromDays(1)      → runs once per day
        Must be at least 1 minute. Precision is to the nearest minute in Windows Task Scheduler.

    .PARAMETER RepeatFor
        A [TimeSpan] controlling the total duration during which the task will repeat.
        Defaults to [TimeSpan]::MaxValue (indefinite, no end date). Examples:
        - [TimeSpan]::FromDays(7)       → repeats for 7 days total
        - [TimeSpan]::FromDays(30)      → repeats for 30 days total
        - [TimeSpan]::FromHours(24)     → repeats for 24 hours total
        When RepeatFor expires, the repeating trigger ends, but the task does not unregister.
        Must be used in conjunction with RepeatEvery to have any effect.

    .PARAMETER RandomDelayMinutes
        Optional random delay (0–120 minutes) added before each trigger fires.
        Default is 0 (no delay). Useful to stagger multiple tasks or avoid "thundering herd"
        when many scheduled tasks would run simultaneously. The delay is applied separately
        to each repetition, not just the first trigger.

    .PARAMETER ExpiresAt
        Optional trigger expiry date and time. When set, the task will not fire after this
        moment, even if RepeatFor has not expired. Accepts a [datetime] object or parseable
        string. If provided with a date/time in the past, the task will not fire at all.
        Unlike RepeatFor, which is a relative duration, ExpiresAt is an absolute cutoff.
        The triggered task entry is removed from Windows Task Scheduler once the expiry
        time is reached.

    .PARAMETER Force
        Overwrites an existing task with the same name without prompting. If a task named
        'LWAS_<MacroName>' already exists, it will be replaced; otherwise a new task is created.

    .OUTPUTS
        PSCustomObject
        Properties: Success [bool], TaskName [string], MacroName [string],
        LauncherPath [string].

    .EXAMPLE
        # Example 1: Simple one-time task (runs once at specified time, no repeat)
        Register-LWASScheduledTask -MacroName 'get-vs-scores' -ProcessName 'lastwar.exe' `
            -StartAt '2026-04-01 08:00'

    .EXAMPLE
        # Example 2: Repeat every 4 hours indefinitely with a random delay to avoid conflicts
        Register-LWASScheduledTask -MacroName 'get-vs-scores' -ProcessName 'lastwar.exe' `
            -StartAt '2026-04-01 08:00' -RepeatEvery ([TimeSpan]::FromHours(4)) `
            -RandomDelayMinutes 15 -Force

    .EXAMPLE
        # Example 3: Run every 30 minutes, repeating for 24 hours from the start time
        Register-LWASScheduledTask -MacroName 'collect-resources' -ProcessName 'lastwar.exe' `
            -StartAt ([datetime]::Now.AddMinutes(5)) `
            -RepeatEvery ([TimeSpan]::FromMinutes(30)) `
            -RepeatFor ([TimeSpan]::FromHours(24)) `
            -Force

    .EXAMPLE
        # Example 4: Daily task at a fixed time with an absolute expiry date
        Register-LWASScheduledTask -MacroName 'daily-check' -ProcessName 'lastwar.exe' `
            -StartAt '2026-04-01 09:00' `
            -RepeatEvery ([TimeSpan]::FromHours(24)) `
            -ExpiresAt '2026-05-01 09:00' `
            -Force

    .EXAMPLE
        # Example 5: Every 6 hours with random delay, limited to 30 days of repetition
        Register-LWASScheduledTask -MacroName 'hourly-task' -ProcessName 'lastwar.exe' `
            -StartAt ([datetime]::Now) `
            -RepeatEvery ([TimeSpan]::FromHours(6)) `
            -RepeatFor ([TimeSpan]::FromDays(30)) `
            -RandomDelayMinutes 10 `
            -Force

    .EXAMPLE
        # Example 6: Every 2 hours with both RepeatFor and ExpiresAt (whichever comes first stops the task)
        $startTime = '2026-04-01 08:00'
        $expiryTime = '2026-05-15 23:59'
        Register-LWASScheduledTask -MacroName 'frequent-task' -ProcessName 'lastwar.exe' `
            -StartAt $startTime `
            -RepeatEvery ([TimeSpan]::FromHours(2)) `
            -RepeatFor ([TimeSpan]::FromDays(45)) `
            -ExpiresAt $expiryTime `
            -RandomDelayMinutes 5 `
            -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$MacroName,

        [Parameter(Mandatory)]
        [string]$ProcessName,

        [Parameter(Mandatory)]
        [datetime]$StartAt,

        [timespan]$RepeatEvery,

        [timespan]$RepeatFor = [TimeSpan]::MaxValue,

        [ValidateRange(0, 120)]
        [int]$RandomDelayMinutes = 0,

        [datetime]$ExpiresAt,

        [switch]$Force
    )

    # Validate macro exists
    $macro = @(Get-LWASMacro -Name $MacroName -ErrorAction SilentlyContinue)
    if ($macro.Count -eq 0) {
        throw "Macro '$MacroName' was not found. Register-LWASScheduledTask requires the macro to exist before registration."
    }

    $taskName     = "LWAS_$MacroName"
    $modulePath   = (Get-Module LastWarAutoScreenshot).Path
    $launcherPath = $null

    try {
        $launcherPath = New-LWASLauncherScript -TaskName $taskName -MacroName $MacroName `
            -ProcessName $ProcessName -ModulePath $modulePath -ErrorAction Stop

        # Build trigger
        if ($PSBoundParameters.ContainsKey('RepeatEvery')) {
            $trigger = New-ScheduledTaskTrigger -Once -At $StartAt -RepetitionInterval $RepeatEvery `
                -ErrorAction Stop
            if ($RepeatFor -ne [TimeSpan]::MaxValue) {
                $trigger.RepetitionDuration = $RepeatFor
            }
        } else {
            $trigger = New-ScheduledTaskTrigger -Once -At $StartAt -ErrorAction Stop
        }

        if ($RandomDelayMinutes -gt 0) {
            $trigger.RandomDelay = [TimeSpan]::FromMinutes($RandomDelayMinutes)
        }

        if ($PSBoundParameters.ContainsKey('ExpiresAt')) {
            $trigger.EndBoundary = $ExpiresAt.ToUniversalTime().ToString('o')
        }

        # Build action
        $action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
            -Argument "-NonInteractive -File ""$launcherPath""" -ErrorAction Stop

        # Build settings
        $settings = Invoke-NewScheduledTaskSettingsSet `
            -ExecutionTimeLimit ([TimeSpan]::FromHours(2)) `
            -StopIfGoingOnBatteries:$false `
            -StartWhenAvailable:$true

        if ($null -eq $settings) {
            throw 'New-ScheduledTaskSettingsSet returned no object; cannot register task.'
        }

        if ($PSCmdlet.ShouldProcess($taskName, 'Register scheduled task')) {
            Invoke-RegisterScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
                -Settings $settings -RunLevel 'Limited' -Force:($Force.IsPresent) -ErrorAction Stop | Out-Null

            Write-LastWarLog -Level Info `
                -Message "Registered scheduled task '$taskName' for macro '$MacroName' (process: '$ProcessName')." `
                -FunctionName 'Register-LWASScheduledTask'
        }
    } catch {
        # Clean up the launcher script if it was created before the failure
        if ($null -ne $launcherPath -and (Test-Path -LiteralPath $launcherPath)) {
            Remove-Item -LiteralPath $launcherPath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Removed launcher script '$launcherPath' after registration failure."
        }
        throw
    }

    return [PSCustomObject]@{
        Success      = $true
        TaskName     = $taskName
        MacroName    = $MacroName
        LauncherPath = $launcherPath
    }
}
