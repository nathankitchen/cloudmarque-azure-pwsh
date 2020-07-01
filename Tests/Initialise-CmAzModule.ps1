function Initialise-CmAzModule
{
    Get-Module "Cloudmarque.Azure" | Remove-Module -Force
    Import-Module "$PSScriptRoot\..\Cloudmarque.Azure\Cloudmarque.Azure.psm1" -Force;
}

Initialise-CmAzModule