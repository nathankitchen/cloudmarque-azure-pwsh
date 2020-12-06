param(
    [Parameter(Mandatory=$true)]
    [String]$ProjectDirectory,
    [Parameter(Mandatory=$true)]
    [String]$Environment,
    [Parameter(Mandatory=$true)]
    [String]$BuildNumber,
    [Parameter(Mandatory=$true)]
    [String]$RepositoryName,
    [Parameter(Mandatory=$true)]
    [String]$DefinitionName,
    [Parameter(Mandatory=$true)]
    [String]$DefinitionVersion
)

$cloudmarque = "Cloudmarque.Azure"

Write-Verbose "Importing $cloudmarque..."
. "$PSScriptRoot\$cloudmarque\Install-Dependencies.ps1"
. "$PSScriptRoot\init.ps1"

Sync-CloudmarqueAzure

# Write out the context before setting it, just in case there's an issue
Write-Verbose "Setting Cloudmarque context..."
Write-Verbose "Project root: $ProjectDirectory"
Write-Verbose "Build ID: $BuildNumber"
Write-Verbose "Repo Name: $RepositoryName"
Write-Verbose "Definition Name: $DefinitionName"
Write-Verbose "Definition Version: $DefinitionVersion"

Set-CmAzContext `
    -Environment $Environment `
    -ProjectRoot $ProjectDirectory `
    -BuildId $BuildNumber `
    -BuildRepoName $RepositoryName `
    -BuildDefinitionName $DefinitionName `
    -BuildDefinitionNumber $DefinitionVersion `
    -ProjectConfirmation "y"
