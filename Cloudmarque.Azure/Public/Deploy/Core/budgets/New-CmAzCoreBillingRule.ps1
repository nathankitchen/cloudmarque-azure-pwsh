function New-CmAzCoreBillingRule {

	<#
		.Synopsis
	 	 Deploys a set of budgets at the subscription level.

		.Description
		 Completes the following:
			* Deploys a set of budgets at the subscription level.
			* Applies filtering via tags (cm-charge: accountnumber) to budgets for resource targeting.
			* Sets the action group to be notified once the threshold for a budget is met.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Core

		.Example
		 New-CmAzCoreBillingRule -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 New-CmAzCoreBillingRule -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploying billing rules")) {

			foreach($budget in $SettingsObject.budgets) {

				Write-Verbose "Validating budget: $($budget.name)..."

				$currentMonth = (Get-Date -Day 1).date

				if (!($budget.startDate -Is [DateTime]) -or $budget.startDate -lt $currentMonth) {
					$budget.startDate = $currentMonth
				}

				if (!($budget.endDate -Is [DateTime]) -or $budget.endDate -le $currentMonth) {
					$budget.endDate = $currentMonth.AddYears(1)
				}

				Write-Verbose "Generating budget name..."
				$budget.name = Get-CmAzResourceName -Resource "Budget" -Architecture "Core" -Region $SettingsObject.location -Name $budget.name

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actiongroup" -ResourceServiceContainer $budget -IsDependency

				$actionGroupResourceId = (Get-CmAzService -Service $budget.service.dependencies.actiongroup -ThrowIfUnavailable -ThrowIfMultiple).resourceId

				# Workaround as ARM templates don't support additional copy objects nested within a copied resource.
				# Required for multiple notifications over multiple budgets.

				Write-Verbose "Creating notifications for budget..."
				$notifications = @{ }

				for ($i = 0; $i -lt $budget.thresholds.count; $i++) {

					$notifications["Notification$i"] = @{
						enabled = $true;
						operator = "GreaterThanOrEqualTo";
						threshold = $budget.thresholds[$i];
						contactGroups = @($actionGroupResourceId);
						contactRoles = @(
							"Owner",
							"Contributor",
							"Reader"
						)
					}
				}

				$budget.notifications = $notifications
			}

			Write-Verbose "Deploying budgets..."
			New-AzDeployment `
				-Location $SettingsObject.location `
				-TemplateFile "$PSScriptRoot\New-CmAzCoreBillingRule.json" `
				-Budgets $SettingsObject.budgets

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}