function New-CmAzMonitorActivityLogAlerts {

	<#
		.Synopsis
		 Allows definition and deployment of activity log alerts for resources/resource groups to set action groups.

		.Description
		 Deploys activity log alert rule at subscription, resource group or resource scope, which in turn are linked to specified action groups.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorActivityLogAlerts -SettingsFile "c:\directory\settingsFile.yml" -Confirm:$false

		.Example
		 New-CmAzMonitorActivityLogAlerts -SettingsObject $settings
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

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy monitor activity log alerts")) {

			$standardDefinitions = Get-CmAzSettingsFile -Path "$PSScriptRoot/standardDefinitions.yml"
			$definitionSeverityNames = $standardDefinitions.Severity.GetEnumerator().Name

			$resourceGroup = Check-MonitorResourceGroup -AlertType "ActivityLog"

			$alerts = @()

			foreach ($group in $SettingsObject.groups) {

				foreach ($alertSet in $group.alertSets) {

					for ($i = 0; $i -lt $alertSet.alerts.count; $i++) {

						$alert = $alertSet.alerts[$i]

						Write-Verbose "Working on Alert group $($alert[$i].name)"

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroups" -ResourceServiceContainer $alert -IsDependency

						if ($definitionSeverityNames -contains $alert.severity) {
							$alert.severity = $standardDefinitions.Severity.$($alert.severity)
						}
						else {
							Write-Verbose "Setting default severity (informational)..."
							$alert.severity = 3
						}

						$alert.actionGroups = @()
						$alert.scopes = @()

						foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
							$alert.actionGroups += @{
								actionGroupId = (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
							}
						}

						foreach ($targetResourceService in $alert.service.dependencies.targetResources) {

							$targetResource = Get-CmAzService -Service $targetResourceService -ThrowIfUnavailable
							$alert.scopes += $targetResource.resourceId
						}

						foreach ($targetResourceGroupService in $alert.service.dependencies.targetResourceGroups) {

							$targetResourceGroup = Get-CmAzService -Service $targetResourceGroupService -ThrowIfUnavailable -IsResourceGroup
							$alert.scopes += $targetResourceGroup.resourceId
						}

                        foreach ($subId in $alert.service.dependencies.targetSubscriptionId) {
							$alert.scopes += "/subscriptions/$subId"
						}

						if ($alert.scopes.count -lt 1){
							$alert.scopes = @("/subscriptions/$((Get-AzContext).Subscription.Id)")
						}

						$alert.description ??= "Activity Log alert"
						$alert.enabled ??= $true

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "activityLogAlert" -ResourceServiceContainer $alert

						$name = $group.name

						if($alertSet.name) {
							$name += "-$($alertSet.name)"
						}

						if($alert.name) {
							$name += "-$($alert.name)"
						}

						$alert.name = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Location $SettingsObject.location -Name "ala-$name-$i"

						$alerts += $alert

						Write-Verbose "Alert: $($alert.name) will be created.."
					}
				}
			}

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Location $resourceGroup.location -Name "New-CmAzMonitorActivityLogAlerts"

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-TemplateFile "$PSScriptRoot\New-CmAzMonitorActivityLogAlerts.json" `
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