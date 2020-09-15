function New-CmAzCoreKeyVault {

	<#
		.Synopsis
		 Creates keyvaults for a specified resource group in the current subscription.

		.Description
		 Completes the following:
			* Deploys multiple keyvaults in multiple locations to a specified resource group.
			* Adds diagnostic settings linking the keyvaults to the core workspace.
			* Adds activity log alert rules for whenever an auditevent is raised in any of the keyvaults.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Core

        .Example
		 New-CmAzCoreKeyVault -SettingsFile "c:/directory/settingsFile.yml"

		.Example
         New-CmAzCoreKeyVault -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory=$true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory=$true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

    try {

		if($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Keyvault")) {

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			if (!$SettingsObject.ResourceGroupName) {
				Write-Error "Please provide a valid resource group name." -Category InvalidArgument -CategoryTargetName "ResourceGroupName"
			}

			if (!$SettingsObject.Location) {
				Write-Error "Please provide a valid location." -Category InvalidArgument -CategoryTargetName "Location"
			}

			if (!$SettingsObject.KeyVaults) {
                Write-Error "Please provide at least one keyvault." -Category InvalidArgument -CategoryTargetName "Keyvaults"
			}

			Write-Verbose "Generating standardised Key Vault names..."
			ForEach ($keyVault in $SettingsObject.KeyVaults) {

				if(!$keyVault.Name -or !$keyVault.Type -or !$keyVault.location) {
					Write-Error "Please ensure a keyvault has a name, a type and a location." -Category InvalidArgument -CategoryTargetName "Keyvaults"
				}

				$keyVault.Name = Get-CmAzResourceName -Resource "KeyVault" -Architecture "Core" -Region $KeyVault.Location -Name $KeyVault.Name -MaxLength 24
			}

			Write-Verbose "Generating keyvault resource group name..."
			$keyVaultResourceGroup = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region $SettingsObject.Location -Name $SettingsObject.ResourceGroupName

			Write-Verbose "Deploying keyvault resource group..."
			New-AzResourceGroup -Location $SettingsObject.Location -Name $keyVaultResourceGroup -Force

			$userObjectID = ""
			$azCtx = (Get-AzContext).Account

			switch ($azCtx.Type)
			{
				"ServicePrincipal" { $userObjectID = $azCtx.Id }
				"User" { $userObjectID = (Get-AzADUser -UserPrincipalName $azCtx.Id).Id }
			}

			$workspace = Get-CmAzService -Service "core.loganalytics" -Region $SettingsObject.Location -ThrowIfUnavailable
			$actionGroup = Get-CmAzService -Service "core.monitoring.actiongroup.priority1" -ThrowIfUnavailable

			Write-Verbose "Deploying keyvaults..."
			New-AzResourceGroupDeployment `
				-TemplateFile "$PSScriptRoot\New-CmAzCoreKeyVault.json" `
				-ResourceGroupName $keyVaultResourceGroup `
				-Keyvaults $SettingsObject.KeyVaults `
				-ActionGroup $actionGroup `
				-Workspace $workspace `
				-ObjectId $UserObjectID `
				-Force

			Write-Verbose "Finished!"
		}
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}
