function Get-LWASScheduledTask {
    <#
    .SYNOPSIS
        Lists Windows Scheduled Tasks registered by LWAS.

    .DESCRIPTION
        Enumerates all scheduled tasks whose names begin with 'LWAS_'. When -MacroName is
        provided, only the task for that macro is returned. For each task, next/last run
        information is retrieved via Get-ScheduledTaskInfo.

        If -MacroName is specified and no matching task is found, a non-terminating error
        is written.

    .PARAMETER MacroName
        Optional. When provided, returns only the task for 'LWAS_<MacroName>'.

    .OUTPUTS
        PSCustomObject[]
        Each object has: TaskName [string], MacroName [string], State [string],
        NextRunTime [datetime], LastRunTime [datetime], LastTaskResult [int],
        LauncherPath [string].

    .EXAMPLE
        Get-LWASScheduledTask

    .EXAMPLE
        Get-LWASScheduledTask -MacroName 'get-vs-scores'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [string]$MacroName
    )

    $allTasks = @(Get-ScheduledTask -TaskName 'LWAS_*' -ErrorAction SilentlyContinue)

    if (-not $PSBoundParameters.ContainsKey('MacroName') -and $allTasks.Count -eq 0) {
        Write-Warning 'No LWAS scheduled tasks found.'
        return
    }

    if ($PSBoundParameters.ContainsKey('MacroName')) {
        $targetName = "LWAS_$MacroName"
        $allTasks = @($allTasks | Where-Object { $_.TaskName -eq $targetName })
        if ($allTasks.Count -eq 0) {
            Write-Error "No scheduled task found for macro '$MacroName'."
            return
        }
    }

    foreach ($task in $allTasks) {
        $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue

        $strippedName = $task.TaskName -replace '^LWAS_', ''
        $launcherPath = Join-Path $env:APPDATA "LastWarAutoScreenshot\Schedulers\$($task.TaskName).ps1"

        [PSCustomObject]@{
            TaskName       = $task.TaskName
            MacroName      = $strippedName
            State          = $task.State
            NextRunTime    = if ($null -ne $info) { $info.NextRunTime }    else { $null }
            LastRunTime    = if ($null -ne $info) { $info.LastRunTime }    else { $null }
            LastTaskResult = if ($null -ne $info) { $info.LastTaskResult } else { $null }
            LauncherPath   = $launcherPath
        }
    }
}
