function Build-CloudmarqueAzure {
    <#
        .Synopsis
        Builds a new version of the Cloudmarque Azure Powershell tooling.
    
        .Description
        Sets the target version number for the module, and then both packs the module
        as a NuGet package.
    
        .Example
        # Build the package
        Build-CloudmarqueAzure -Version "1.0.0" -Suffix "nightly"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Suffix = "dev"
    )

    $module = "Cloudmarque.Azure";

    $prereleaseMarker = @{
        PSData = @{
            Prerelease = $Suffix
            Tags = 'Azure','PSEdition_Core','PSEdition_Desktop','Windows','Linux','macOS'
        }
    }

    $functionNames = Get-ChildItem -Path "$PSScriptRoot\$module\Public\" -Filter "*.ps1" -Recurse -Force -PipelineVariable file | ForEach-Object { $file.BaseName }

    Update-ModuleManifest -Path "$PSScriptRoot\$module\$module.psd1" -FunctionsToExport $functionNames -ModuleVersion $Version -PrivateData $prereleaseMarker

    New-Item -Path "$PSScriptRoot\publish\" -Name $Project -ItemType Directory -Force | Out-Null
    New-Item -Path "$PSScriptRoot\publish\pkg\" -Name $Project -ItemType Directory -Force | Out-Null

    Remove-Item -Path "$PSScriptRoot\publish\pkg\*"

    Get-ChildItem "$PSScriptRoot\" -Filter "*.ps1" | Copy-Item -Destination "$PSScriptRoot\publish\"

    nuget pack "$PSScriptRoot\$module\$module.nuspec" -Version $Version -OutputDirectory "$PSScriptRoot\publish\pkg\" -Properties NoWarn=NU5110,NU5111
}