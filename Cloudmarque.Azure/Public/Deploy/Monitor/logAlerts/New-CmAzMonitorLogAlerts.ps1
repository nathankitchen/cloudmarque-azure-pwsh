function New-CmAzMonitorLogAlerts {

	<#
		.Synopsis
		 Allows definiton and deployment of log alerts to set action groups.

		.Description
		 Deploys log alert rules using custom log analytics queries to specfied action groups, this can be used in the following ways:
			* Utilising the default log alert rule definition for the deployment.
			* Overriding the default log alert rule definition with custom query, schedule, threshold and severity values, additional custom parameters can also be passed.
			* On top of the above, custom actions specifying email subjects and webhook json payloads can be specified.
			* Custom reusable log alert rule definitions can also be defined and deployed.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
         File path for settings containing tags definition.

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorLogAlerts -SettingsFile "c:\directory\settingsFile.yml"

		.Example
		 New-CmAzMonitorLogAlerts -SettingsObject $settings
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

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy monitor log alerts")) {

			$standardDefinitions = Get-CmAzSettingsFile -Path "$PSScriptRoot/standardDefinitions.yml"

			$workspace = Get-CmAzService -Service $SettingsObject.service.dependencies.workspace -ThrowIfUnavailable -ThrowIfMultiple

			$alerts = @()

			foreach ($group in $SettingsObject.groups) {

				foreach ($alertSet in $SettingsObject.groups.alertSets) {

					for ($i = 0; $i -lt $alertSet.alerts.count; $i++) {
	
						$alert = $alertSet.alerts[$i]
	
						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroups" -ResourceServiceContainer $alert -IsDependency
	
						$definition = $standardDefinitions.Queries.$($alertSet.type) | Where-Object { $_.name -eq $alert.name }
	
						if (!$definition) {
							Write-Error "$($alert.name) is not a valid definition..." -Category InvalidArgument -CategoryTargetName "name"
						}
	
						if ($definition.defaults) {
	
							foreach ($default in $definition.defaults.GetEnumerator()) {
	
								$placeHolder = "@@@$($default.name)@@@"
	
								if (!$alert.parameters.$($default.name)) {
	
									Write-Verbose "$($default.name): No parameter found. Setting default value..."
									$value = $default.value
								}
								else{
									$value = $alert.parameters.$($default.name)
								}
	
								$definition.query = $definition.query.replace($placeHolder, $value)
							}
						}
	
						$alert.enabled ??= $true
	
						$alert.schedule ??= @{
							frequencyInMinutes = $definition.schedule.frequencyInMinutes;
							timeWindowInMinutes = $definition.schedule.timeWindowInMinutes;
						}
	
						$alert.threshold ??= @{
							Operator = $definition.threshold.Operator;
							value = $definition.threshold.value;
						}
	
						if ($standardDefinitions.Severity.GetEnumerator().Name -contains $alert.severity) {
							$alert.severity = $standardDefinitions.Severity.$($alert.severity)
						}
						else {
							Write-Verbose "Setting default severity..."
							$alert.severity = $definition.severity
						}
	
						$alert.description ??= $definition.description
	
						$alert.actionGroupInfo = @{ actionGroup = @(); }
	
						foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
							$alert.actionGroupInfo.actionGroup += (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
						}
	
						if($alert.customisedActions) {
	
							$alert.actionGroupInfo.emailSubject = $alert.customisedActions.emailSubject
							$alert.actionGroupInfo.customWebhookPayload = $alert.customisedActions.webhookJsonPayload
						}
	
						$alertName = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Region $workspace.location -Name "$($group.name)-$($alertSet.type)-$i"
	
						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "logAlert" -ResourceServiceContainer $alert
	
						$alerts += @{
							name = $alertName;
							enabled = $alert.enabled;
							query = $definition.query;
							schedule = $alert.schedule;
							aznsAction = $alert.actionGroupInfo;
							threshold = $alert.threshold;
							description = $alert.description;
							severity = $alert.severity;
							service = $alert.service;
						}
					}
				}
			}

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Region $workspace.location -Name $MyInvocation.MyCommand.Name

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-TemplateFile "$PSScriptRoot\New-CmAzMonitorLogAlerts.json" `
				-ResourceGroupName $workspace.resourceGroupName `
				-Alerts $alerts `
				-Workspace $workspace `
				-Force

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}