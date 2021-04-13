function New-CmAzMonitorMetricAlerts {

	<#
		.Synopsis
		 Allows definiton and deployment of metric alerts for resources/resource groups to set action groups.

		.Description
		 Deploys multi-resource single-metric alert rules at either a resource group or resource scope, which in turn are linked to specified action groups.
		 The metric name is used to specify the metric rule used, all rules specified can have a customisable threshold, comparison operator, 
		 time aggregation, severity and schedule values. Metric alerts are only available if the resources/resources groups specified in the scope share the same location.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
         File path for settings containing tags definition.

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorMetricAlerts -SettingsFile "c:\directory\settingsFile.yml"

		.Example
		 New-CmAzMonitorMetricAlerts -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[string]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[object]$SettingsObject,
		[AllowEmptyString()]
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy monitor metric alerts")) {

			$standardDefinitions = Get-CmAzSettingsFile -Path "$PSScriptRoot/standardDefinitions.yml"
			$definitionSeverityNames = $standardDefinitions.Severity.GetEnumerator().Name

			$alerts = @()

			foreach ($group in $SettingsObject.groups) {

				foreach ($alertSet in $group.alertSets) {

					for ($i = 0; $i -lt $alertSet.alerts.count; $i++) {

						$alert = $alertSet.alerts[$i]

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroups" -ResourceServiceContainer $alert -IsDependency

						if ($definitionSeverityNames -contains $alert.severity) {
							$alert.severity = $standardDefinitions.Severity.$($alert.severity)
						}
						else {
							Write-Verbose "Setting default severity (informational)..."
							$alert.severity = 3
						}

						if ($alert.schedule) {

							$alert.schedule.frequencyInMinutes = $standardDefinitions.frequencyInMinutes[$alert.schedule.frequencyInMinutes.ToString()]
							$alert.schedule.timeWindowInMinutes = $standardDefinitions.timeWindowInMinutes[$alert.schedule.timeWindowInMinutes.ToString()]
						}
						else {

							Write-Verbose "Setting default schedule..."
							$alert.schedule = @{
								frequencyInMinutes = "PT1M"
								timeWindowInMinutes = "PT5M"
							}
						}

						$alert.actionGroups = @()
						$alert.scopes = @()

						foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
							$alert.actionGroups += @{
								actionGroupId = (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
							}
						}

						foreach ($resource in $alert.service.dependencies.resources) {

							$resourceService = Get-CmAzService -Service $resource -ThrowIfUnavailable
							$alert.scopes += ($resourceService | Where-object { $_.location -eq $alert.location.replace(' ', '') }).resourceId
						}

						foreach ($resourceGroup in $alert.service.dependencies.resourceGroups) {

							$resourceGroupService = Get-CmAzService -Service $resourceGroup -ThrowIfUnavailable -IsResourceGroup
							$alert.scopes += ($resourceGroupService).resourceId
						}

						$alert.description ??= "Alert for $($alert.metricName) on $($alertSet.resourceType)"

						$resourceGroup = $resourceGroupService ? $resourceGroupService.resourceGroupName : $resourceService.ResourceGroupName

						$alert.enabled ??= $true

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "metricAlert" -ResourceServiceContainer $alert

						$alerts += @{
							name = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Region $alert.location -Name "$($group.name)-$i-$($alert.threshold.value)"
							metricName = $alert.metricName
							resourceGroup = $resourceGroup -is [System.Array] ? $resourceGroup[0] : $resourceGroup
							resourceType = $alertSet.resourceType
							location = $alert.location
							schedule = $alert.schedule
							actionGroups = $alert.actionGroups
							scopes = $alert.scopes
							threshold = $alert.threshold
							severity = $alert.severity
							service = $alert.service
							description = $alert.description
							enabled = $alert.enabled
						}
					}
				}
			}

			$location = $alerts.location -is [System.Array] ? $alerts[0].location : $alerts.location

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Region $location -Name "New-CmAzMonitorMetricAlerts"

			New-AzDeployment `
				-Name $deploymentName `
				-TemplateFile "$PSScriptRoot\New-CmAzMonitorMetricAlerts.json" `
				-Alerts $alerts `
				-location $location

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}