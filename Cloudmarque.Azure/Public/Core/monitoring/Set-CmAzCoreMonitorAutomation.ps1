function Set-CmAzCoreMonitorLoggingAutomation {

	<#
		.Synopsis
		 Sets core monitor automation settings.

		.Description
		 Sets scehdules in the core automation account for updating vms.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Core

		.Example
		 Set-CmAzCoreMonitorLoggingAutomation -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 Set-CmAzCoreMonitorLoggingAutomation -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[string]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Core Logging Automation")) {

		if ($SettingsFile -and !$SettingsObject) {
			$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
		}
		elseif (!$SettingsFile -and !$SettingsObject) {
			Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
		}

		$schedules = [System.Collections.ArrayList]@()

		foreach ($scheduleSetting in  $SettingsObject.WindowsUpdateSchedules) {

			$updateTypes = ""

			switch ($scheduleSetting.UpdateType) {
				"Critical" { $updateTypes = "Critical, Security, UpdateRollup" }
				"CriticalSecurity" { $updateTypes = "Critical, Security, UpdateRollup, Definition" }
				"Recommended" { $updateTypes = "Critical, Security, UpdateRollup, Definition, ServicePack" }
				"All" { $updateTypes = "Critical, Security, UpdateRollup, Definition, ServicePack, FeaturePack, Tools, Updates" }
				Default {
					Write-Error "Update type not recognised." -Category InvalidArgument -CategoryTargetName "UpdateType"
				}
			}

			$frequencyTagValue = ""

			if ($scheduleSetting.Frequency -eq "Week") {
				$frequencyTagValue = (get-date $scheduleSetting.StartTime).DayOfWeek
			}
			else {
				$frequencyTagValue = $scheduleSetting.Frequency
			}

			$schedule = @{
				"updateTypes" = $updateTypes;
				"tagValue"    = "$($scheduleSetting.UpdateType).$($frequencyTagValue)";

				# Create schedule details in a schema that matches the arm template
				"details"     = @{
					"expiryTime" = $scheduleSetting.ExpiryTime;
					"frequency"  = $scheduleSetting.Frequency;
					"interval"   = 1;
					"name"       = Get-CmAzResourceName -Resource "AutomationSchedule" -Architecture "Core" -Region $SettingsObject.Location -Name $scheduleSetting.Name;
					"startTime"  = $scheduleSetting.StartTime;
					"timeZone"   = "Europe/London"
				}
			}

			$schedules.Add($schedule)
		}

		$automationAccount = Get-CmAzService -Service 'testtest12' -Region $SettingsObject.Location -ThrowIfUnavailable
		$workspace = Get-CmAzService -Service 'core.loganalytics1' -Region $SettingsObject.Location -ThrowIfUnavailable

		Write-Verbose "Deploying Core Logging Automation..."
		New-AzResourceGroupDeployment `
			-ResourceGroupName $workspace.resourceGroupName `
			-TemplateFile "$PSScriptRoot/Set-CmAzCoreMonitor.Automation.json" `
			-AutomationAccountName $automationAccount.name `
			-UpdateSchedules $schedules `
			-WorkspaceName $workspace.name `
			-Force
	}
}