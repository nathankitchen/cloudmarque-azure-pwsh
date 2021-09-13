function Check-MonitorResourceGroup {

    param (
        [string]$AlertType
    )

    Write-Verbose "Checking resource group for alerts..."
    if (!$SettingsObject.service.dependencies.resourceGroup -and !$SettingsObject.service.publish.resourceGroup) {
        Write-Error "Require resource group information for resource health alerts..." -Category NotSpecified -CategoryTargetName "ResourceGroup"
    }

    $SettingsObject.service.dependencies.resourceGroup ??= $SettingsObject.service.publish.resourceGroup

    $resourceGroup = Get-CmAzService -Service $SettingsObject.service.dependencies.resourceGroup -IsResourceGroup -ThrowIfMultiple

    if (!$resourceGroup) {

        if (!$SettingsObject.location -or !$SettingsObject.service.publish.resourceGroup) {
            Write-Error "Require location and service to create resource group for resource health alerts..." -Category NotSpecified -CategoryTargetName "ResourceGroup"
        }

        Write-Verbose "Generating resource names..."
        $resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Monitor" -Location $SettingsObject.location -Name "$AlertType-Alerts"

        Write-Verbose "Deploying resource group ($resourceGroupName)..."
        $resourceGroup = New-AzResourceGroup `
            -Name $resourceGroupName `
            -Location $SettingsObject.location `
            -Tag @{ "cm-service" = $SettingsObject.service.publish.resourceGroup } `
            -Force
    }

    Write-Verbose "Alert will be deployed on Resource Group: $($resourceGroup.resourceGroupName)"

    $SettingsObject.location = $resourceGroup.location

    return $resourceGroup
}