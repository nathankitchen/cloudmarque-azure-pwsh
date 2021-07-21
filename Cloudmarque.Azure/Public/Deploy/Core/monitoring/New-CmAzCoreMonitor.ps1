function New-CmAzCoreMonitor {

	<#
		.Synopsis
		 Deploys monitoring for core resources.

		.Description
		 Completes the following:
			* Deploys log analytics, app insights and storage accountp.
			* Deploys management solutions for keyvaults, subscription activity, agent health, updates and VM insights.
		 	* Deploys action groups and alerts for service health, keyvault admin and resource health for applicable core resources.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
         File path for settings containing tags definition.

		.Component
		 Core

		.Example
		 New-CmAzCoreMonitor -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 New-CmAzCoreMonitor -SettingsObject $settings
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

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Core Monitoring")) {

			foreach ($key in $SettingsObject.alerts.keys) {

				$alert = $SettingsObject.alerts[$key]

				if (($SettingsObject.actionGroups | Where-Object { $_.name -eq $alert.actionGroupName}).count -eq 0) {
					Write-Error "Action group $($alert.actionGroupName) not found in settings." -Category InvalidArgument -CategoryTargetName "actionGroupName"
				}
			}

			$appInsights = Get-CmAzResourceName -Resource "ApplicationInsights" -Architecture "Core" -Location $SettingsObject.location -Name $SettingsObject.name
			$workspace = Get-CmAzResourceName -Resource "LogAnalyticsWorkspace" -Architecture "Core" -Location $SettingsObject.location -Name $SettingsObject.name

			$workbookService = Get-CmAzService -Service $SettingsObject.service.publish.workbook

			$workbook = @{
				DisplayName = Get-CmAzResourceName -Resource "Workbook" -Architecture "Core" -Location $SettingsObject.location -Name "workspaceUsage-$($SettingsObject.name)"
				Category = "workbook"
				Guid = New-Guid
				exists = $workbookService ? $true : $false
				serializedJson = (Get-CmAzSettingsFile -path "$PSScriptRoot/WorkspaceUsage.workbook.json") | ConvertTo-Json -Compress -Depth 100
			}

			Write-Verbose "Formatting action group receivers..."
			$receiverTypes = @("armRoles", "emails", "functions", "itsm", "logicApps", "notifications", "runbooks", "sms", "voice", "webhooks")
			$receiverTypesWithCommonSchema = @("armRoles", "emails", "functions", "logicApps", "runbooks", "webhooks")

			$nameKey = "name"

			foreach ($actionGroup in $SettingsObject.actionGroups) {

				if(!$actionGroup.name -or !$actionGroup.shortName) {
					Write-Error "Please ensure a action group has a name, a shortname and at least one receiver." -Category InvalidArgument -CategoryTargetName "ActionGroups"
				}

				foreach ($receiverType in $receiverTypes) {

					$receivers = $actionGroup[$receiverType]

					if (!$receivers) {
						$actionGroup[$receiverType] = @()
						continue
					}

					for ($j = 0; $j -lt $receivers.count; $j++) {

						$receiver = $receivers[$j]
						$receiver[$nameKey] = Get-CmAzResourceName -Resource "ActionGroupReceiver" -Architecture "Core" -Location "Global" -Name "$($actionGroup[$nameKey])$($receiverType)-$($j)"

						if ($receiverTypesWithCommonSchema -Contains $receiverType) {
							$receiver.useCommonAlertSchema = $true
						}
					}
				}

				$actionGroup[$nameKey] = Get-CmAzResourceName -Resource "ActionGroup" -Architecture "Core" -Location "Global" -Name $actionGroup[$nameKey]

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroup" -ResourceServiceContainer $actiongroup
			}

			Write-Verbose "Setting alerts..."
			$keyvaultAdminAlert = @{
				$nameKey = Get-CmAzResourceName -Resource "Alert" -Architecture "Core" -Location "Global"-Name "$($SettingsObject.name)-KeyvaultAdmin";
				"actionGroupName" = Get-CmAzResourceName -Resource "ActionGroup" -Architecture "Core" -Location "Global" -Name $SettingsObject.alerts.keyvaultAdmin.actionGroupName;
				"enabled" = $SettingsObject.alerts.keyvaultAdmin.enabled ??= $false;
				"servicePublish" = $SettingsObject.service.publish.keyvaultAdminAlert;
				"conditions" = @(
					@{
						"field" = "category";
						"equals" = "Administrative";
					},
					@{
						"field" = "resourceType";
						"equals" = "Microsoft.Keyvault/Vaults";
					}
				);
			}

			$resourceHealthAlert = @{
				$nameKey = Get-CmAzResourceName -Resource "Alert" -Architecture "Core" -Location "Global"-Name "$($SettingsObject.name)-ResourceHealth";
				"actionGroupName" = Get-CmAzResourceName -Resource "ActionGroup" -Architecture "Core" -Location "Global" -Name $SettingsObject.alerts.resourceHealth.actionGroupName;
				"enabled" = $SettingsObject.alerts.resourceHealth.enabled ??= $false;
				"servicePublish" = $SettingsObject.service.publish.resourceHealthAlert;
				"conditions" = @(
					@{
						"field" = "category";
						"equals" = "ResourceHealth";
					},
					@{
						"field" = "resourceType";
						"equals" = "Microsoft.Keyvault/Vaults";
					},
					@{
						"field" = "resourceType";
						"equals" = "Microsoft.OperationalInsights/Workspaces";
					},
					@{
						"field" = "resourceType";
						"equals" = "Microsoft.Storage/StorageAccounts";
					}
				);
			}

			$serviceHealthAlert = @{
				$nameKey = Get-CmAzResourceName -Resource "Alert" -Architecture "Core" -Location "Global"-Name "$($SettingsObject.name)-ServiceHealth";
				"actionGroupName" = Get-CmAzResourceName -Resource "ActionGroup" -Architecture "Core" -Location "Global" -Name $SettingsObject.alerts.serviceHealth.actionGroupName;
				"enabled" = $SettingsObject.alerts.serviceHealth.enabled ??= $false;
				"servicePublish" = $SettingsObject.service.publish.serviceHealthAlert;
				"conditions" = @(
					@{
					   "field" = "category";
					   "equals" = "ServiceHealth";
					},
					@{
					   "field" = "properties.impactedServices[*].ImpactedRegions[*].RegionName";
					   "containsAny" = $SettingsObject.alerts.serviceHealth.impactedLocations ?? @($SettingsObject.location);
					}
				);
			}

			$SettingsObject.alerts = @($keyvaultAdminAlert, $resourceHealthAlert, $serviceHealthAlert)
			$SettingsObject.workspaceDataRetentionInDays ??= 90

			Write-Verbose "Generating resource names..."
			$resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Location $SettingsObject.Location -Name $SettingsObject.name

			Write-Verbose "Deploying resource group ($resourceGroupName)..."
			New-AzResourceGroup `
				-Name $resourceGroupName `
				-Location $SettingsObject.location `
				-Tag @{ "cm-service" = $SettingsObject.service.publish.resourceGroup } `
				-Force

			Write-Verbose "Deploying storage..."
			$storageObject = @{

				location = $SettingsObject.location;
				service = @{
					dependencies = @{
						resourceGroup = $SettingsObject.service.publish.resourceGroup
					};
					publish = @{
						storage = $SettingsObject.service.publish.storage
					}
				}
				storageAccounts = @(@{
					storageAccountName = $SettingsObject.name;
					accountType = "Standard";
					blobContainer = @(
						@{ name = "insights-logs-addonazurebackuppolicy"},
						@{ name = "insights-logs-azurebackupreport"},
						@{ name = "insights-logs-coreazurebackup"},
						@{ name = "insights-logs-networksecuritygroupflowevent"}
					)
				})
			}

			New-CmAzIaasStorage -SettingsObject $storageObject -OmitTags

			Write-Verbose "Deploying monitor resources..."

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Core" -Location $SettingsObject.Location -Name "New-CmAzCoreMonitor"

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-ResourceGroupName $resourceGroupName `
				-TemplateFile "$PSScriptRoot/New-CmAzCoreMonitor.json" `
				-ActionGroups $SettingsObject.actionGroups `
				-Alerts $SettingsObject.alerts `
				-AppInsightsName $appInsights `
				-WorkspaceDataRetentionInDays $SettingsObject.workspaceDataRetentionInDays `
				-ServiceContainer $SettingsObject.service.publish `
				-WorkspaceName $workspace `
				-Workbook $workbook `
				-Force > $Null

			Write-Verbose "Setting advisor configuration cpu threshold..."
			Set-AzAdvisorConfiguration -LowCpuThreshold $SettingsObject.AdvisorLowCPUThresholdPercentage

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds @($resourceGroupName)

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}