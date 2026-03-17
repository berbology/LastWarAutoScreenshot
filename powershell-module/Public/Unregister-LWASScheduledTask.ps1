function Unregister-LWASScheduledTask {
    <#
    .SYNOPSIS
        Removes a LWAS Windows Scheduled Task and deletes its launcher script.

    .DESCRIPTION
        Looks up the scheduled task named 'LWAS_<MacroName>' and, after confirmation,
        unregisters it and deletes the corresponding launcher .ps1 file from
        $env:APPDATA\LastWarAutoScreenshot\Schedulers\.

        If the task does not exist, a warning is emitted and the function returns without
        taking action.

        Supports -WhatIf and -Confirm via ShouldProcess.

    .PARAMETER MacroName
        The macro name whose scheduled task should be removed (without the 'LWAS_' prefix).

    .PARAMETER Force
        Skips the ShouldProcess confirmation prompt.

    .EXAMPLE
        Unregister-LWASScheduledTask -MacroName 'get-vs-scores'

    .EXAMPLE
        Unregister-LWASScheduledTask -MacroName 'get-vs-scores' -Force

    .NOTES
        The launcher .ps1 file is always deleted alongside the scheduled task to prevent
        orphaned scripts in the Schedulers directory.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$MacroName,

        [switch]$Force
    )

    $taskName = "LWAS_$MacroName"

    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -eq $existingTask) {
        Write-Warning "No scheduled task found for macro '$MacroName'."
        return
    }

    $launcherPath = Join-Path $env:APPDATA "LastWarAutoScreenshot\Schedulers\$taskName.ps1"

    if ($PSCmdlet.ShouldProcess($taskName, 'Unregister scheduled task and delete launcher script')) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

        if (Test-Path -LiteralPath $launcherPath) {
            Remove-Item -Path $launcherPath -Force -ErrorAction SilentlyContinue
        }

        Write-LastWarLog -Level Info `
            -Message "Unregistered scheduled task '$taskName' and deleted launcher script '$launcherPath'." `
            -FunctionName 'Unregister-LWASScheduledTask'
    }
}
