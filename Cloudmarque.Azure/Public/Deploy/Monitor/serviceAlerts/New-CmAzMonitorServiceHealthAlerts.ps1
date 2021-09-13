function New-CmAzMonitorServiceHealthAlerts {

	<#
		.Synopsis
		 Allows definition and deployment of service health alerts.

		.Description
		 Deploys service health alerts, which in turn are linked to specified action groups.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorServiceHealthAlerts -SettingsFile "c:\directory\settingsFile.yml" -Confirm:$false

		.Example
		 New-CmAzMonitorServiceHealthAlerts -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[string]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[object]$SettingsObject,
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy service health alerts")) {

			$resourceGroup = Check-MonitorResourceGroup -AlertType "ServiceHealth"

			$alerts = @()

			foreach ( $alert in $SettingsObject.alerts ) {

				Write-Verbose "Working on Alert group $($alert.name)"

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroups" -ResourceServiceContainer $alert -IsDependency

				$alert.actionGroups = @()

				foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
					$alert.actionGroups += @{
						actionGroupId = (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
					}
				}

				$alert.description ??= "Service health alert"
				$alert.enabled ??= $true

				$alert.name = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Location $SettingsObject.location -Name $alert.name

				$alert.condition = @{
					allOf = @(
						@{
							field  = "category"
							equals = "ServiceHealth"
						}
					)
				}

				$trackedEvents = @()

				foreach ( $eventType in $alert.eventTypes ) {

					$trackedEvents += @{
						field =  "properties.incidentType"
						equals = $eventType
					}
				}

				if ( !$trackedEvents ) {

					$trackedEvents += @{
						field =  "properties.incidentType"
						equals = "Incident"
					}
				}

				$alert.condition.allOf += @{ anyOf = $trackedEvents }

				$alert.condition.allOf += @{
					field = "properties.impactedServices[*].ImpactedRegions[*].RegionName"
					containsAny = $alert.regions
				}

				if ( !$alert.services ) {
					$alert.condition.allOf += @{
						field = "properties.impactedServices[*].ServiceName"
						containsAny = @($alert.services)
					}
				}

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "serviceHealthAlert" -ResourceServiceContainer $alert

				$alerts += $alert

				Write-Verbose "Alert: $($alert.name) will be created.."
			}

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Location $resourceGroup.location -Name "New-CmAzMonitorServiceHealthAlerts"

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-TemplateFile "$PSScriptRoot\New-CmAzMonitorServiceHealthAlerts.json" `
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