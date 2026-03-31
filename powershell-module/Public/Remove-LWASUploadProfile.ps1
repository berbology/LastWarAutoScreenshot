function Remove-LWASUploadProfile {
    <#
    .SYNOPSIS
        Removes a saved upload profile and optionally removes its associated SAS token.

    .DESCRIPTION
        Looks up the named profile and, after optional confirmation, deletes it from the
        profiles directory. If the profile references a SAS token environment variable
        (sasTokenEnvVar), the function checks whether any other existing upload profiles
        also reference the same SAS token variable.

        If no other profiles reference the SAS token:
        - The SAS token environment variable is removed via Remove-LWASSasToken.

        If other profiles reference the same SAS token:
        - A verbose message is written listing which profiles still use it, and the
          SAS token is left intact.

        Use -Force to skip the interactive confirmation prompt.
        Supports -WhatIf: the profile file is not deleted when -WhatIf is active.

    .PARAMETER Name
        Name(s) of the upload profile(s) to remove. Accepts a single string or an array of strings.

    .PARAMETER Force
        Skips the interactive confirmation prompt.

    .OUTPUTS
        None

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1'

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1', 'azure-2'

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1' -Force

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1' -WhatIf

    .EXAMPLE
        Remove-LWASUploadProfile -Name 'azure-1' -Force
        # If no other profiles use its SAS token, the token is removed automatically.
        # If other profiles use it, a verbose message indicates which profiles still reference it.

    .EXAMPLE
        Get-LWASUploadProfile -Name 'profile-1', 'profile-2' | Remove-LWASUploadProfile -Force
        # Pipes profile objects returned by Get-LWASUploadProfile directly into Remove-LWASUploadProfile.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [Parameter()]
        [switch]$Force
    )

    process { foreach ($profileName in $Name) {
        $uploadProfile = Get-UploadProfile -Name $profileName
        if ($null -eq $uploadProfile) {
            Write-Error "Upload profile '$profileName' not found."
            continue
        }

        if (-not $Force) {
            $confirmation = Read-Host "Remove upload profile '$profileName'? This cannot be undone. [Y/N]"
            if ($confirmation -notin @('Y', 'y')) {
                continue
            }
        }

        if ($PSCmdlet.ShouldProcess($profileName, 'Remove upload profile')) {
            # Get the SAS token env var name from the profile
            $sasTokenEnvVar = $uploadProfile.sasTokenEnvVar

            # Remove the profile file
            $filePath = Join-Path (Join-Path $env:APPDATA 'LastWarAutoScreenshot\UploadProfiles') "$profileName.json"
            Remove-Item -LiteralPath $filePath -Force -ErrorAction SilentlyContinue

            Write-LastWarLog -Level Info `
                -Message "Upload profile '$profileName' removed ('$filePath')." `
                -FunctionName 'Remove-LWASUploadProfile'

            # Check if any other profiles reference the same SAS token env var
            if (-not [string]::IsNullOrEmpty($sasTokenEnvVar)) {
                $allProfiles = @(Get-UploadProfile)
                $otherProfilesUsingToken = @($allProfiles |
                    Where-Object { $_.name -ne $profileName -and $_.sasTokenEnvVar -eq $sasTokenEnvVar })

                if ($otherProfilesUsingToken.Count -eq 0) {
                    # No other profiles use this token, so remove it
                    try {
                        Remove-LWASSasToken -Name $sasTokenEnvVar -ErrorAction Stop
                        Write-Verbose "SAS token environment variable '$sasTokenEnvVar' removed (no longer used by any upload profile)."
                    } catch {
                        Write-Warning "Failed to remove SAS token environment variable '$sasTokenEnvVar': $_"
                    }
                } else {
                    # Other profiles still use this token
                    $otherProfileNames = $otherProfilesUsingToken | Select-Object -ExpandProperty name
                    Write-Verbose "SAS token environment variable '$sasTokenEnvVar' is still used by other upload profiles: $($otherProfileNames -join ', '). Skipping removal."
                }
            }

            Write-Verbose "Upload profile '$profileName' removed."
        }
    } } # end foreach / end process
}
