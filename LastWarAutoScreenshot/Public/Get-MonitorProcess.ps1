function Get-MonitorProcess {
    param($processId)
    try {
        return [System.Diagnostics.Process]::GetProcessById($processId)
    } catch {
        Write-LastWarLog -Message "Failed to get process for monitoring: $_" -Level Warning -FunctionName 'Start-WindowAndProcessMonitor' -Context "ProcessId: $processId"
        return $null
    }
}
