function Set-CmAzIaasUpdateManagement {

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

		$automationAccount = Get-CmAzService -Service $SettingsObject.service.dependencies.automation -ThrowIfUnavailable -ThrowIfMultiple

		Write-Verbose "Fetching schedule settings.."
		$scheduleTypeSettingsObject = Get-CmAzSettingsFile -Path "$PSScriptRoot/scheduleTypes.yml"

		if (!$scheduleTypeSettingsObject) {
			Write-Error "No valid schedule settings." -Category ObjectNotFound -CategoryTargetName "scheduleTypeSettingsObject"
		}

		$schedules = [System.Collections.ArrayList]@()

		foreach ($scheduleSetting in  $SettingsObject.WindowsUpdateSchedules) {

			$updateTypes = $scheduleTypeSettingsObject.updateGroups[$scheduleSetting.UpdateGroup]

			if (!$updateTypes) {
				Write-Error "Update type not recognised." -Category InvalidArgument -CategoryTargetName "updateTypes"
			}

			$frequency = $scheduleTypeSettingsObject.updateFrequencies[$scheduleSetting.Frequency]

			if (!$frequency) {
				Write-Error "Frequency not recognised." -Category InvalidArgument -CategoryTargetName "frequency"
			}

			$currentDate = (Get-Date).date.addDays(1)

			if (!($scheduleSetting.startTime -Is [DateTime]) -or $scheduleSetting.startTime -lt $currentDate) {
				$scheduleSetting.startTime = $currentDate
			}

			if (!($scheduleSetting.expiryTime -Is [DateTime]) -or $scheduleSetting.expiryTime -le $currentDate) {
				$scheduleSetting.expiryTime = $currentDate.AddYears(1)
			}

			if(!$scheduleSetting.location) {
				$scheduleSetting.location = $SettingsObject.location
			}

			$schedule = @{
				"updateTypes" = $updateTypes;
				"tagValue"    = "";
				"location"    =  $scheduleSetting.location;
				# Create schedule details in a schema that matches the arm template
				"details"     = @{
					"expiryTime" = $scheduleSetting.expiryTime;
					"frequency"  = $frequency;
					"interval"   = 1;
					"name"       = Get-CmAzResourceName -Resource "AutomationSchedule" -Architecture "Core" -Region $scheduleSetting.Location -Name $scheduleSetting.Name;
					"startTime"  = $scheduleSetting.StartTime;
					"timeZone"   = "Europe/London";
					"advancedSchedule" = @{
						"weekDays" 	= @();
						"monthDays" = @();
						"monthlyOccurrences" = @();
					};
				}
			}

			$updateGroupTag = $scheduleSetting.UpdateGroup
			$frequencyTag = $scheduleSetting.Frequency

			Write-Verbose "Update schedule set to $($frequency).."
			if ($frequency -eq $scheduleTypeSettingsObject.updateFrequencies.weekly) {

				$dayOfWeek = (Get-Date $scheduleSetting.StartTime).DayOfWeek
				$frequencyTag = $dayOfWeek
				$schedule.details.advancedSchedule.weekDays += $dayOfWeek
			}
			elseif ($frequency -eq $scheduleTypeSettingsObject.updateFrequencies.monthly) {

				$schedule.details.advancedSchedule.monthDays += (get-date $scheduleSetting.StartTime).Day
			}

			$schedule.tagValue = "$($updateGroupTag)-$($frequencyTag)".ToLower()

			$schedules.Add($schedule) > $null
		}

		Write-Verbose "Deploying Schedule Management..."
		New-AzResourceGroupDeployment `
			-ResourceGroupName $automationAccount.resourceGroupName `
			-TemplateFile "$PSScriptRoot/Set-CmAzIaasUpdateManagement.json" `
			-AutomationAccountName $automationAccount.name `
			-UpdateSchedules $schedules `
			-Force
	}
}