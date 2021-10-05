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

		.Component
		 Monitor

		.Example
		 New-CmAzMonitorLogAlerts -SettingsFile "c:\directory\settingsFile.yml" -Confirm:$false

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

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy monitor log alerts")) {

			$standardDefinitions = Get-CmAzSettingsFile -Path "$PSScriptRoot/standardDefinitions.yml"

			$workspace = Get-CmAzService -Service $SettingsObject.service.dependencies.workspace -ThrowIfUnavailable -ThrowIfMultiple

			$resourceGroup = Check-MonitorResourceGroup -AlertType "Log"

			$alerts = @()

			foreach ($group in $SettingsObject.groups) {

				foreach ($alertSet in $SettingsObject.groups.alertSets) {

					$query = $standardDefinitions.Queries.($alertSet.type)

					for ($i = 0; $i -lt $alertSet.alerts.count; $i++) {

						$alert = $alertSet.alerts[$i]

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroups" -ResourceServiceContainer $alert -IsDependency

						if ($alert.definition) {

    						$definition = $query | Where-Object { $_.definition -eq $alert.definition }

							if (!$definition) {
								Write-Error "$($alert.definition) is not a valid definition..." -Category InvalidArgument -CategoryTargetName "definition"
							}

							if (!$alert.schedule) {
								$alert.schedule = $definition.schedule
							}

							if (!$alert.severity) {
								$alert.severity = $definition.severity
							}

							if (!$alert.suppress) {
								$alert.suppress = $definition.suppress
							}

							if (!$alert.threshold) {
								$alert.threshold = $definition.threshold
							}

							if (!$alert.description) {
								$alert.description = $definition.description
							}

							if (!$alert.description) {
								$alert.description = $definition.description
							}

							if (!$alert.query) {

								foreach ($default in $definition.defaults?.GetEnumerator()) {

									$placeHolder = "@@@$($default.name)@@@"

									if (!$alert.parameters.$($default.name)) {
										$value = $default.value
									}
									else {
										$value = $alert.parameters.$($default.name)
									}

									$definition.query = $definition.query.replace($placeHolder, $value)
								}

								$alert.query = $definition.query
							}
						}


						$errorMessage = "Please provide a valid {0} for alert {1}"

						if (!$alert.schedule) {
							Write-Error ($errorMessage -f "schedule", $alert.name) -Category InvalidArgument -CategoryTargetName "schedule"
						}

						if ($null -eq $alert.severity) {
							Write-Error ($errorMessage -f "severity", $alert.name) -Category InvalidArgument -CategoryTargetName "severity"
						}
						elseif (!$standardDefinitions.Severity.GetEnumerator().name -contains $alert.severity) {
							Write-Error "Please use an existing severity definition for alert $($alert.name)" -Category InvalidArgument -CategoryTargetName "severity"
						}

						if (!$alert.suppress) {
							Write-Error ($errorMessage -f "suppress", $alert.name) -Category InvalidArgument -CategoryTargetName "supress"
						}

						if (!$alert.threshold) {
							Write-Error ($errorMessage -f "threshold", $alert.name) -Category InvalidArgument -CategoryTargetName "threshold"
						}

						if (!$alert.description) {
							Write-Error ($errorMessage -f "description", $alert.name) -Category InvalidArgument -CategoryTargetName "description"
						}

						if (!$alert.query) {
							Write-Error ($errorMessage -f "query", $alert.name) -Category InvalidArgument -CategoryTargetName "query"
						}

						if (!$alert.suppress -or !$alert.suppress.enabled) {
							$alert.suppress = ""
						}

						if (!$alert.monitorOnPrem) {
							$alert.query += "`n| where isnotempty(_ResourceId) and isnotnull(_ResourceId)"
						}

						$alert.enabled ??= $true
						$alert.severity = $standardDefinitions.Severity.$($alert.severity)
						$alert.actionGroupInfo = @{ actionGroup = @(); }

						foreach ($actionGroup in $alert.service.dependencies.actionGroups) {
							$alert.actionGroupInfo.actionGroup += (Get-CmAzService -Service $actionGroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId
						}

						if ($alert.customisedActions) {

							$alert.actionGroupInfo.emailSubject = $alert.customisedActions.emailSubject
							$alert.actionGroupInfo.customWebhookPayload = $alert.customisedActions.webhookJsonPayload
						}

						$name = $group.name

						if ($alertSet.name) {
							$name += "-$($alertSet.name)"
						}

						if ($alert.name) {
							$name += "-$($alert.name)"
						}

						$alertName = Get-CmAzResourceName -Resource "Alert" -Architecture "Monitor" -Location $workspace.location -Name "log-$name-$i"

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "logAlert" -ResourceServiceContainer $alert

						$alerts += @{
							name        = $alertName;
							enabled     = $alert.enabled;
							query       = $alert.query;
							suppress    = $alert.suppress;
							schedule    = $alert.schedule;
							aznsAction  = $alert.actionGroupInfo;
							threshold   = $alert.threshold;
							description = $alert.description;
							severity    = $alert.severity;
							service     = $alert.service;
						}
					}
				}
			}

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Monitor" -Location $workspace.location -Name $MyInvocation.MyCommand.Name

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-TemplateFile "$PSScriptRoot\New-CmAzMonitorLogAlerts.json" `
				-ResourceGroupName $resourceGroup.resourceGroupName `
				-TemplateParameterObject @{
					Alerts    = $alerts
					Workspace = $workspace
				}`
				-Mode "Complete"

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroup.resourceGroupName

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}