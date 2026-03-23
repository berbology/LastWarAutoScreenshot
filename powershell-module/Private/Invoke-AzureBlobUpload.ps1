function Invoke-AzureBlobUpload {
    <#
    .SYNOPSIS
        Uploads a single file to Azure Blob Storage via the REST API.

    .DESCRIPTION
        Constructs a PUT request URL for Azure Blob Storage and uploads the file using
        Invoke-WebRequest. Retries on transient failures via Invoke-WithRetry.

        The SAS token is accepted directly as a parameter — the caller is responsible
        for reading it from the environment variable. This separation keeps the function
        directly testable without env var dependencies.

    .PARAMETER FilePath
        Absolute path to the local file to upload.

    .PARAMETER AccountName
        Azure Storage account name (e.g. 'mystorageaccount').

    .PARAMETER ContainerName
        Name of the blob container (e.g. 'screenshots').

    .PARAMETER BlobPath
        Destination blob path within the container (e.g. 'my-macro/2026-03-21/file.png').

    .PARAMETER SasToken
        SAS token string (without leading '?'). Appended to the PUT URL as a query string.

    .PARAMETER MaxRetryAttempts
        Maximum number of upload attempts. Default: 3.

    .PARAMETER RetryBaseDelayMs
        Base delay in milliseconds for retry backoff. Default: 500.

    .OUTPUTS
        PSCustomObject
        On success: @{ Success = $true;  BlobUrl = <string>; FilePath = <string> }
        On failure: @{ Success = $false; Message = <string>; FilePath = <string> }

    .EXAMPLE
        $result = Invoke-AzureBlobUpload -FilePath 'C:\screenshots\img.png' `
            -AccountName 'myaccount' -ContainerName 'screenshots' `
            -BlobPath 'my-macro/2026-03-21/img.png' -SasToken $env:LWAS_AZURE_SAS_TOKEN_1
        if ($result.Success) { Write-Host "Uploaded to $($result.BlobUrl)" }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$AccountName,

        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$BlobPath,

        [Parameter(Mandatory)]
        [string]$SasToken,

        [Parameter()]
        [int]$MaxRetryAttempts = 3,

        [Parameter()]
        [int]$RetryBaseDelayMs = 500
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        $message = "File not found: '$FilePath'."
        Write-LastWarLog -Level Error -Message $message -FunctionName 'Invoke-AzureBlobUpload'
        return [PSCustomObject]@{
            Success  = $false
            Message  = $message
            FilePath = $FilePath
        }
    }

    # Strip a leading '?' from the SAS token to avoid double-encoding
    $cleanSas = $SasToken.TrimStart('?')
    $url = "https://$AccountName.blob.core.windows.net/$ContainerName/$BlobPath`?$cleanSas"

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    try {
        Invoke-WithRetry -MaxAttempts $MaxRetryAttempts -BaseDelayMs $RetryBaseDelayMs -ScriptBlock {
            Invoke-WebRequest -Uri $url -Method Put -Body $bytes `
                -Headers @{ 'x-ms-blob-type' = 'BlockBlob' } `
                -UseBasicParsing -ErrorAction Stop | Out-Null
        }

        Write-LastWarLog -Level Info `
            -Message "Successfully uploaded '$FilePath' to '$url'." `
            -FunctionName 'Invoke-AzureBlobUpload'

        return [PSCustomObject]@{
            Success  = $true
            BlobUrl  = $url
            FilePath = $FilePath
        }
    } catch {
        $message = "Failed to upload '$FilePath' after $MaxRetryAttempts attempt(s): $_"
        Write-LastWarLog -Level Error -Message $message -FunctionName 'Invoke-AzureBlobUpload'
        return [PSCustomObject]@{
            Success  = $false
            Message  = $message
            FilePath = $FilePath
        }
    }
}
