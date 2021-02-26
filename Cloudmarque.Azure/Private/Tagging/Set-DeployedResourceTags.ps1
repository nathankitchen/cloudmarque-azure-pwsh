function Set-DeployedResourceTags() {

    param(
        [AllowEmptyString()]
        [String]$TagSettingsFile,
        [Parameter(ParameterSetName = "Resources")]
        [AllowEmptyCollection()]
        [Array]$ResourceIds,
        [Parameter(ParameterSetName = "ResourceGroups")]
        [AllowEmptyCollection()]
        [Array]$ResourceGroupIds
    )

    if (!$ResourceIds -and !$ResourceGroupIds) {
        Write-Warning "No resources provided for tagging."
        return
    }

    if ($TagSettingsFile) {
        $SettingsObject = Get-CmAzSettingsFile -Path $TagSettingsFile
    }
    else {
        $SettingsObject = Get-CmAzSettingsFile -Path "$((Get-CmAzContext).projectRoot)/_tags/globalTags.yml"
    }

    if ($ResourceIds) {
        $SettingsObject.resourceIds = @()
        $SettingsObject.resourceIds += $ResourceIds | Where-Object { $_ }
    }
    elseif ($ResourceGroupIds) {
        $SettingsObject.resourceGroupIds = @()
        $SettingsObject.resourceGroupIds += $ResourceGroupIds | Where-Object { $_ }
    }

    Write-Verbose "Setting tagging details for deployed resources..."
    Set-CmAzTag -SettingsObject $SettingsObject > $null
}