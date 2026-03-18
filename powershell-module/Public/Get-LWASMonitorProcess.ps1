function Get-LWASMonitorProcess {
    <#
    .SYNOPSIS
        Returns a Process object for the given process ID, or $null if the
        process is not found.

    .DESCRIPTION
        Wraps [System.Diagnostics.Process]::GetProcessById to suppress the
        exception thrown when the process does not exist. Used internally by
        Start-WindowAndProcessMonitor to obtain the process object required
        for exit detection.

        Returns $null and logs a Warning when the process cannot be found —
        for example, when the game has already exited before monitoring starts.

    .PARAMETER ProcessId
        The numeric ID of the process to look up.

    .OUTPUTS
        System.Diagnostics.Process
        The process object for the given ID, or $null if the process is not
        found or has already exited.

    .EXAMPLE
        $process = Get-LWASMonitorProcess -ProcessId 12345
        if ($null -eq $process) {
            Write-Warning 'Process not found'
        }

    .EXAMPLE
        $window = Get-LWASTargetWindow -ProcessName 'lastwar.exe' -First
        $process = Get-LWASMonitorProcess -ProcessId $window.ProcessId
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$ProcessId
    )
    try {
        return [System.Diagnostics.Process]::GetProcessById($ProcessId)
    } catch {
        Write-LastWarLog -Message "Failed to get process for monitoring: $_" -Level Warning -FunctionName 'Start-WindowAndProcessMonitor' -Context "ProcessId: $ProcessId"
        return $null
    }
}

