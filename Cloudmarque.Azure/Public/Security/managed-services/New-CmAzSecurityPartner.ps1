﻿function New-CmAzPartner {

	<#
		.Synopsis
		 Deploys Trustmarque Managed Service security groups to a target subscription.

		.Description
		 Uses security groups to add permissions for third-party service providers to
		 access resources for management in a target subscription.

		.Parameter SettingsFile
		 The path to the location of the settings file describing partner access roles to
		 the target subscriptions.

		.Parameter SettingsObject
		 A settings object describing the settings to apply (uses the same structure as
		 the settings file)

		.Example
		 New-CmAzSecurityPartner `
			--SubscriptionId "4b16b463-43cc-49d2-84a2-05c76c005cd6" `
			--CustomerGroupId "96785a54-5489-4e7c-b33b-1eac26fc0163"
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)
	try {

		Get-CmAzContext -RequireAzure

		foreach ($partner in $SettingsObject.Partners) {

			if ($PSCmdlet.ShouldProcess($SubscriptionId, "Allow $($partner.name) access to current subscription")) {
				New-AzDeployment `
					-Name "Cloudmarque.Azure.Partner" `
					-TemplateParameterFile "./_templates/azuredeploy.parameters.json" `
					-TemplateFile "./_templates/azuredeploy.json" `
					-customerGroupId $CustomerGroupId
			}
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem)
	}
}