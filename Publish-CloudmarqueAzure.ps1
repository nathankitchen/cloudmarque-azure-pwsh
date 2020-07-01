function Publish-CloudmarqueAzure {

    <#
        .Synopsis
         Publishes a new version of the Cloudmarque Azure Powershell tooling.
    
        .Description
         Sets the target version number for the module, and then both packs and publishes
         the module as a NuGet package.
    
        .Example
         Publish-CloudmarqueAzure -Package "$PSScriptRoot\publish\pkg\$module.*.nupkg"
    #>

    [CmdletBinding()]
    param(
        [string]$Username,
        [string]$Password,
        [Parameter(Mandatory=$true)]
        [String]$Package
    )

    $configFile = "$PSScriptRoot/nuget.config"

    if ($Username -and $Password) {
        nuget sources Add -Name "Cloudmarque" -Source "" -username $Username -password $Password -configfile $configFile
    }
    else {
        nuget sources Add -Name "Cloudmarque" -Source ""
    }

    nuget push -Source "Cloudmarque" -ApiKey AzureDevOpsServices $Package -configfile $configFile -NonInteractive -SkipDuplicate
}