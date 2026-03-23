function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a scriptblock with exponential-backoff retry on retryable HTTP errors.

    .DESCRIPTION
        Executes $ScriptBlock up to $MaxAttempts times. On failure:
        - If the exception carries an HTTP status code in $RetryOnHttpStatus, waits
          min(BaseDelayMs * 2^(attempt-1) + random(0, BaseDelayMs), 30000) ms then retries.
        - For any other exception (non-HTTP or non-retryable status code): re-throws immediately.
        After exhausting MaxAttempts: re-throws the last exception.
        Logs each retry attempt at Warning level via Write-LastWarLog.

    .PARAMETER ScriptBlock
        The scriptblock to execute.

    .PARAMETER MaxAttempts
        Maximum total number of attempts (including the first). Default: 3.

    .PARAMETER BaseDelayMs
        Base delay in milliseconds for the retry backoff formula. Default: 500.

    .PARAMETER RetryOnHttpStatus
        HTTP status codes that trigger a retry. Default: 429, 500, 502, 503, 504.

    .OUTPUTS
        System.Object
        The value returned by $ScriptBlock on success.

    .EXAMPLE
        $result = Invoke-WithRetry -ScriptBlock { Invoke-WebRequest -Uri $url -Method Put } `
            -MaxAttempts 3 -BaseDelayMs 500
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxAttempts = 3,

        [Parameter()]
        [int]$BaseDelayMs = 500,

        [Parameter()]
        [int[]]$RetryOnHttpStatus = @(429, 500, 502, 503, 504)
    )

    $lastException = $null

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return (& $ScriptBlock)
        } catch {
            $lastException = $_

            # Attempt to extract an HTTP status code from the exception
            $statusCode = $null
            if ($null -ne $_.Exception -and
                $_.Exception -is [System.Net.Http.HttpRequestException] -and
                $null -ne $_.Exception.StatusCode) {
                $statusCode = [int]($_.Exception.StatusCode)
            } elseif ($null -ne $_.Exception -and
                      $null -ne $_.Exception.Response -and
                      $null -ne $_.Exception.Response.StatusCode) {
                $statusCode = [int]($_.Exception.Response.StatusCode)
            }

            $isRetryable = ($null -ne $statusCode) -and ($RetryOnHttpStatus -contains $statusCode)

            if (-not $isRetryable) {
                throw
            }

            if ($attempt -ge $MaxAttempts) {
                # Exhausted all attempts
                throw
            }

            # Calculate bounded exponential backoff with jitter
            $exponential = $BaseDelayMs * [Math]::Pow(2, $attempt - 1)
            $jitter      = Get-Random -Minimum 0 -Maximum $BaseDelayMs
            $delayMs     = [Math]::Min($exponential + $jitter, 30000)

            Write-LastWarLog -Level Warning `
                -Message "Invoke-WithRetry: Attempt $attempt of $MaxAttempts failed with HTTP $statusCode. Retrying in $([int]$delayMs) ms." `
                -FunctionName 'Invoke-WithRetry'

            Start-Sleep -Milliseconds ([int]$delayMs)
        }
    }
}
