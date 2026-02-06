Get-ChildItem -Path "$PSScriptRoot\public", "$PSScriptRoot\private" -Filter *.ps1 | ForEach-Object { . $_ }   

Get-ChildItem -Path "$PSScriptRoot\public" -Filter *.ps1 | ForEach-Object { Export-ModuleMember -Function $_.BaseName }   
