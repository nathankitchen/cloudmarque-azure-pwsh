function New-CmAzCoreKeyVault {

	<#
		.Synopsis
		 Creates keyvaults for a specified resource group in the current subscription.

		.Description
		 Completes the following:
			* Deploys multiple keyvaults in multiple locations to a specified resource group.
			* Adds diagnostic settings linking the keyvaults to the core workspace.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
         File path for settings containing tags definition.

		.Component
		 Core

        .Example
		 New-CmAzCoreKeyVault -SettingsFile "c:/directory/settingsFile.yml"

		.Example
         New-CmAzCoreKeyVault -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[AllowEmptyString()]
		[String]$TagSettingsFile
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

			if (!$SettingsObject.resourceGroupName) {
				Write-Error "Please provide a valid resource group name." -Category InvalidArgument -CategoryTargetName "ResourceGroupName"
			}

			if (!$SettingsObject.location) {
				Write-Error "Please provide a valid location." -Category InvalidArgument -CategoryTargetName "Location"
			}

			if (!$SettingsObject.keyVaults) {
                Write-Error "Please provide at least one keyvault." -Category InvalidArgument -CategoryTargetName "Keyvaults"
			}

			$workspace = Get-CmAzService -Service $SettingsObject.service.dependencies.workspace -ThrowIfUnavailable -ThrowIfMultiple

			Write-Verbose "Generating standardised Key Vault names..."
			ForEach ($keyVault in $SettingsObject.keyVaults) {

				if(!$keyVault.name -or !$keyVault.type -or !$keyVault.location) {
					Write-Error "Please ensure a keyvault has a name, a type and a location." -Category InvalidArgument -CategoryTargetName "Keyvaults"
				}

				$keyVault.name = Get-CmAzResourceName -Resource "KeyVault" -Architecture "Core" -Region $keyVault.location -Name $keyVault.name -MaxLength 24

				if($null -eq $keyVault.enableSoftDelete) {
					$keyVault.enableSoftDelete = $true;
				}

				if($null -eq $keyVault.enablePurgeProtection) {
					$keyVault.enablePurgeProtection = $true;
				}
	
				if (!$keyVault.softDeleteRetentionInDays) {
					$keyVault.softDeleteRetentionInDays = 90;
				}

				Write-Verbose "Generating keyvault passwords.."
				$keyvault.secrets = [System.Collections.ArrayList]@()

				$secretValues = New-Secret -Count $keyvault.secretNames.count

				For ($i = 0; $i -lt $keyvault.secretNames.count; $i++) {
					$keyvault.secrets.add(@{ name = $keyvault.secretNames[$i]; value = $secretValues[$i]; }) > $null
				}

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "keyvault" -ResourceServiceContainer $keyVault
			}

			Write-Verbose "Generating keyvault resource group name..."
			$keyVaultResourceGroup = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region $SettingsObject.location -Name $SettingsObject.resourceGroupName

			Write-Verbose "Deploying keyvault resource group..."
			New-AzResourceGroup -Location $SettingsObject.location -Name $keyVaultResourceGroup -Tag @{ "cm-service" = $SettingsObject.service.publish.resourceGroup } -Force

			$azCtx = (Get-AzContext).account

			switch ($azCtx.type)
			{
				"ServicePrincipal" { 
					$objectId = (Get-AzADServicePrincipal -ApplicationId $azCtx.Id).id 
				}
				"User" { 
					$objectId = (Get-AzADUser -UserPrincipalName $azCtx.id).id 
				}
			}

			Write-Verbose "Deploying Keyvaults..."
			New-AzResourceGroupDeployment `
				-TemplateFile "$PSScriptRoot\New-CmAzCoreKeyVault.json" `
				-ResourceGroupName $keyVaultResourceGroup `
				-KeyvaultDetails $SettingsObject `
				-ObjectId $objectId `
				-Workspace $workspace `
				-Force

			Write-Verbose "Generating key encryption keys..."
			$SettingsObject.keyvaults | ForEach-Object -Parallel {

				$keyvault = $_

				if(!$keyvault.encryptionKeyNames) {
					$keyvault.encryptionKeyNames = @()
				}

				$keyvault.encryptionKeyNames | ForEach-Object -Parallel {
					Add-AzKeyVaultKey -Name $_ -VaultName $using:keyvault.name -Destination "Software" > $null
				}
			}

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $keyVaultResourceGroup

			Write-Verbose "Finished!"
		}
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}
