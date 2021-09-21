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

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorMetricAlerts -SettingsFile "c:\directory\settingsFile.yml" -Confirm:$false

		.Example
		 New-CmAzMonitorMetricAlerts -SettingsObject $settings
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

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy monitor metric alerts")) {

			$standardDefinitions = Get-CmAzSettingsFile -Path "$PSScriptRoot/standardDefinitions.yml"
			$definitionSeverityNames = $standardDefinitions.Severity.GetEnumerator().Name

			$resourceGroup = Check-MonitorResourceGroup -AlertType "Metric"

			$alerts = @()

			foreach ($group in $SettingsObject.groups) {

				foreach ($alertSet in $group.alertSets) {

					for ($i = 0; $i -lt $alertSet.alerts.count; $i++) {

						$alert = $alertSet.alerts[$i]

						$name = $group.name

						if($alertSet.name) {
							$name += "-$($alertSet.name)"
						}

						if($alert.name) {
							$name += "-$($alert.name)"
						}

						$alert.name = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Location $alert.targetResourceLocation -Name "mtr-$name-$i"

						Write-Verbose "Working on alert: $($alert.name)"

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
						$alert.criterias = @()

						for ($j = 0; $j -lt $alert.conditions.count; $j++) {

							$alert.conditions[$j].dimensions ??= @()

							$alert.criterias += @{

								name = "Alert Criteria $j"
								metricName = $alert.conditions[$j].metricName
								metricNamespace = $alertSet.resourceType
								dimensions = $alert.conditions[$j].dimensions
								operator = $alert.conditions[$j].threshold.operator
								threshold = $alert.conditions[$j].threshold.value
								timeAggregation = $alert.conditions[$j].threshold.timeAggregation
							}
						}

						foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
							$alert.actionGroups += @{
								actionGroupId = (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
							}
						}

						foreach ($targetResourceService in $alert.service.dependencies.targetResources) {

							$targetResource = Get-CmAzService -Service $targetResourceService -ThrowIfUnavailable
							$alert.scopes += ($targetResource | Where-object { $_.location -eq $alert.targetResourceLocation.replace(' ', '') -and $_.resourceType -eq $alertSet.resourceType}).resourceId
						}

						foreach ($targetResourceGroupService in $alert.service.dependencies.targetResourceGroups) {

							$targetResourceGroup = Get-CmAzService -Service $targetResourceGroupService -ThrowIfUnavailable -IsResourceGroup
							$alert.scopes += $targetResourceGroup.resourceId
						}

						$alert.description ??= "Alert for $($alert.metricName) on $($alertSet.resourceType)"
						$alert.enabled ??= $true

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "metricAlert" -ResourceServiceContainer $alert

						$alert += @{
							resourceType = $alertSet.resourceType
						}

						$alerts += $alert
					}
				}
			}

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Location $resourceGroup.location -Name "New-CmAzMonitorMetricAlerts"

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-TemplateFile "$PSScriptRoot\New-CmAzMonitorMetricAlerts.json" `
				-ResourceGroupName $resourceGroup.resourceGroupName `
				-Alerts $alerts `
				-Mode "Complete"

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroup.resourceGroupName

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}