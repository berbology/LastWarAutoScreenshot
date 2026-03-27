function Test-LWASAzureProfile {
    <#
    .SYNOPSIS
        Returns $true if the supplied upload profile has cloudProvider set to 'azure'.

    .DESCRIPTION
        A silent bool guard used by SAS-related functions to ensure they are operating
        on an Azure profile before performing any Az module or environment variable
        operations. Does not write any errors or warnings — consistent with the Test-*
        convention. The caller is responsible for composing an appropriate error message.

    .PARAMETER Profile
        The upload profile PSCustomObject to inspect.

    .OUTPUTS
        System.Boolean
        $true if $UploadProfile.cloudProvider -ieq 'azure'; $false in all other cases
        (missing field, null, empty string, or any other value).

    .EXAMPLE
        if (-not (Test-LWASAzureProfile -UploadProfile $uploadProfile)) {
            Write-Error "SAS token management requires an Azure profile."
            return $false
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$UploadProfile
    )

    if ($null -eq $UploadProfile.PSObject.Properties['cloudProvider']) {
        return $false
    }

    return $UploadProfile.cloudProvider -ieq 'azure'
}
