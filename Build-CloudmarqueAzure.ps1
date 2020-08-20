function Build-CloudmarqueAzure {
    
    <#
        .Synopsis
         Sets release details for the module.

        .Description
         Sets the following on the module's manifest file:
            * Exported functions
            * Module version
            * Release notes
            * Pre-release suffix

        .Example
         Build-CloudmarqueAzure -Version "1.0.0" -Suffix "nightly" -ReleaseNotes "Initial Release"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$Suffix,
        [string]$ReleaseNotes
    )

    $module = "Cloudmarque.Azure";

    $functionNames = Get-ChildItem `
        -Path "$PSScriptRoot\$module\Public\" `
        -Filter "*.ps1" `
        -Recurse `
        -Force `
        -PipelineVariable file | ForEach-Object { $file.BaseName }

    Update-ModuleManifest `
        -Path "$PSScriptRoot\$module\$module.psd1" `
        -FunctionsToExport $functionNames `
        -ModuleVersion $Version `
        -ReleaseNotes $ReleaseNotes `
        -PreRelease $Suffix
}