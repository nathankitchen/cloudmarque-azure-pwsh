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

	$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

	Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

	if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Core Logging Automation")) {

		Write-Verbose "Removing pre-existing Automation JobSchedules..."
		$automationAccount = Get-CmAzService -Service $SettingsObject.service.dependencies.automation -ThrowIfUnavailable -ThrowIfMultiple

		$existingJobSchedules = Get-AzAutomationScheduledRunbook `
			-ResourceGroupName $automationAccount.resourceGroupName `
			–AutomationAccountName $automationAccount.name `
			-RunbookName "Patch-MicrosoftOMSComputers"

		if ($existingJobSchedules) {

			ForEach ($existingJobSchedule in $existingJobSchedules) {

				Unregister-AzAutomationScheduledRunbook `
					-JobScheduleId $existingJobSchedule.JobScheduleId `
					-ResourceGroupName $automationAccount.resourceGroupName `
					–AutomationAccountName $automationAccount.name `
					-Force
			}
		}

		Write-Verbose "Fetching schedule settings.."
		$scheduleTypeSettingsObject = Get-CmAzSettingsFile -Path "$PSScriptRoot/scheduleTypes.yml"

		if (!$scheduleTypeSettingsObject) {
			Write-Error "No valid schedule settings." -Category ObjectNotFound -CategoryTargetName "scheduleTypeSettingsObject"
		}

		$schedules = [System.Collections.ArrayList]@()

		foreach ($scheduleSetting in  $SettingsObject.WindowsUpdateSchedules) {

			$updateTypes = $scheduleTypeSettingsObject.updateGroups[$scheduleSetting.UpdateGroup]

			$frequency = $scheduleTypeSettingsObject.updateFrequencies[$scheduleSetting.Frequency]

			$currentDate = (Get-Date).date.addDays(1)

			if (!($scheduleSetting.startTime -Is [DateTime]) -or $scheduleSetting.startTime -lt $currentDate) {
				$scheduleSetting.startTime = $currentDate
			}

			if (!($scheduleSetting.expiryTime -Is [DateTime]) -or $scheduleSetting.expiryTime -le $currentDate) {
				$scheduleSetting.expiryTime = $null
			}

			if (!$scheduleSetting.location) {
				$scheduleSetting.location = $SettingsObject.location
			}

			$schedule = @{
				"updateTypes" = $updateTypes;
				"tagValue"    = "";
				"location"    = $scheduleSetting.location;

				# Create schedule details in a schema that matches the arm template
				"details"     = @{
					"expiryTime"       = $scheduleSetting.expiryTime;
					"frequency"        = $frequency;
					"interval"         = 1;
					"name"             = Get-CmAzResourceName -Resource "AutomationSchedule" -Architecture "Core" -Region $scheduleSetting.Location -Name $scheduleSetting.Name;
					"startTime"        = $scheduleSetting.startTime;
					"timeZone"         = "Europe/London";
					"advancedSchedule" = @{
					};
				}
			}

			$updateGroupTag = $scheduleSetting.UpdateGroup
			$frequencyTag = $scheduleSetting.Frequency

			Write-Verbose "Update schedule set to $($frequency).."
			if ($frequency -eq $scheduleTypeSettingsObject.updateFrequencies.weekly) {

				$frequencyTag = $scheduleSetting.dayOfWeek
				$schedule.details.advancedSchedule.weekDays = @($scheduleSetting.dayOfWeek)
			}
			elseif ($frequency -eq $scheduleTypeSettingsObject.updateFrequencies.monthly) {

				$schedule.details.advancedSchedule.monthDays = @($scheduleSetting.dateOfMonth)
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