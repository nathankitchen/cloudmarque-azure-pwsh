function New-CmAzMonitorResourceHealthAlerts {

    <#
		.Synopsis
		 Allows definition and deployment of resource health alerts.

		.Description
		 Deploys resource health alert rule at subscription, resource group or resource scope, which in turn are linked to specified action groups.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorResourceHealthAlerts -SettingsFile "c:\directory\settingsFile.yml" -Confirm:$false

		.Example
		 New-CmAzMonitorResourceHealthAlerts -SettingsObject $settings
	#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [string]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [object]$SettingsObject
    )

    $ErrorActionPreference = "Stop"

    try {

        Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

        $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy resource health alerts")) {

            $resourceGroup = Check-MonitorResourceGroup -AlertType "ResourceHealth"

            $alerts = @()

            foreach ( $alert in $SettingsObject.alerts ) {

                Write-Verbose "Working on Alert: $($alert.name)"

                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroups" -ResourceServiceContainer $alert -IsDependency

                $alert.actionGroups = @()

                foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
                    $alert.actionGroups += @{
                        actionGroupId = (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
                    }
                }

                $alert.description ??= "Resource health alert"
                $alert.enabled ??= $true

                $alert.name = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Location $SettingsObject.location -Name $alert.name

                $alert.condition = @{
                    allOf = @(
                        @{
                            field  = "category"
                            equals = "ResourceHealth"
                        }
                    )
                }

                if ($alert.service.dependencies.targetResourceGroups) {

                    $targetResourceGroups = @()

                    foreach ($targerResourceGroupService in $alert.service.dependencies.targetResourceGroups) {

                        $rgService = Get-CmAzService -Service $targerResourceGroupService -IsResourceGroup -ThrowIfUnavailable

                        foreach ($rg in $rgService) {

                            $targetResourceGroups += @{
                                field  = "resourceGroup"
                                equals = $rg.ResourceGroupName
                            }
                        }
                    }

                    $alert.condition.allOf += @{
                        anyOf = $targetResourceGroups
                    }
                }

                if ($alert.service.dependencies.targetResources) {

                    $targetResources = @()

                    foreach ($targetResourceService in $alert.service.dependencies.targetResources) {

                        $resourceService = Get-CmAzService -Service $targetResourceService -ThrowIfUnavailable

                        foreach ($resource in $resourceService) {

                            $targetResources += @{
                                field  = "resourceId"
                                equals = $resource.resourceName
                            }
                        }
                    }

                    $alert.condition.allOf += @{
                        anyOf = $targetResources
                    }
                }

                function Add-Condition {

                    param(
                        [AllowEmptyString()]
                        [string]$field,
                        [AllowEmptyCollection()]
                        [Array]$resources
                    )

                    if ($resources) {

                        Write-Verbose "Custom field found: $field..."
                        $conditions = @()

                        foreach ($resource in $resources) {

                            $conditions += @{
                                field  = $field
                                equals = $resource
                            }
                        }

                        $alert.condition.allOf += @{
                            anyOf = $conditions
                        }
                    }
                }

                Add-Condition -field "resourceType" -resources $alert.resourceTypes
                Add-Condition -field "status" -resources $alert.eventStatus
                Add-Condition -field "properties.cause" -resources $alert.reasonType

                Add-Condition -field "properties.currentHealthStatus" -resources $alert.healthStatus.current
                Add-Condition -field "properties.previousHealthStatus" -resources $alert.healthStatus.previous

                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "serviceHealthAlert" -ResourceServiceContainer $alert

                $alerts += $alert

                Write-Verbose "Alert: $($alert.name) will be created.."
            }

            $deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Location $SettingsObject.location -Name "New-CmAzMonitorResourceHealthAlerts"

            New-AzResourceGroupDeployment `
                -Name $deploymentName `
                -TemplateFile "$PSScriptRoot\New-CmAzMonitorResourceHealthAlerts.json" `
                -ResourceGroupName $resourceGroup.resourceGroupName `
                -Mode "Complete" `
                -TemplateParameterObject @{
                    Alerts = $alerts
                }

            Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroup.resourceGroupName

            Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}