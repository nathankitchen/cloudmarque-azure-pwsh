function New-CmAzCoreAutomation {

	<#
		.Synopsis
		 Create an Automation account with runbooks. This cmdlet relies on functionality in Azure that is currently 'preview' status.

		.Description
		 Completes the following:
			* Creates Resource Group for automation account.
			* Creates Automation account for runbook, dsc or both.
			* Optionally assigns system managed identity to automation account. (preview)
			* Optionally assigns Azure role to managed identity. (preview)

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
         File path for settings containing tags definition.

		.Component
		 Core

		.Example
		 New-CmAzCoreAutomation -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 New-CmAzCoreAutomation -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[AllowEmptyString()]
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Cloudmarque Core Automation Stack")) {

			$workspace = Get-CmAzService -Service $SettingsObject.service.dependencies.workspace -ThrowIfUnavailable -ThrowIfMultiple

			if ($SettingsObject.automation.sourceControl.url) {

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "keyvault" -ResourceServiceContainer $SettingsObject.automation.sourceControl -IsDependency

				$keyVault = Get-CmAzService -Service $SettingsObject.automation.sourceControl.service.dependencies.keyvault -ThrowIfUnavailable -ThrowIfMultiple

				$repoUrl = $SettingsObject.automation.sourceControl.url
				$repoType = $SettingsObject.automation.sourceControl.type
				$folderPath = $SettingsObject.automation.sourceControl.folderPath
				$keyVaultPersonalAccessToken = $SettingsObject.automation.sourceControl.keyVaultPersonalAccessToken
				$branch = $SettingsObject.automation.sourceControl.branch

				if (!$branch) {
					$branch = "master"
				}

				if (!$repoType) {
					$repoType = "github"
				}

				$repoType = $repoType.ToLower()

				if (!$folderPath) {
					$folderPath = "/"
				}

				$personalAccessToken = (Get-AzKeyVaultSecret -VaultName $keyVault.resourceName -Name $keyVaultPersonalAccessToken).SecretValue

				if (!$personalAccessToken) {
					Write-Error "No PAT found on key vault."
				}

				Write-Verbose "Repository settings are found to be ok, SCM integration will be attempted..."
			}
			else {
				Write-Verbose "No Repository provided, SCM Intergration will be skipped..."
			}

			Write-Verbose "Generating resource names..."
			$resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Location $SettingsObject.automation.location -Name $SettingsObject.automation.name

			Write-Verbose "Deploying resource group ($resourceGroupName)..."
			New-AzResourceGroup `
				-Name $resourceGroupName `
				-Location $SettingsObject.automation.location `
				-Tag @{ "cm-service" = $SettingsObject.service.publish.resourceGroup } `
				-Force

			Write-Verbose "Creating Automation Account..."
			$automationAccountName = Get-CmAzResourceName -Resource "Automation" -Architecture "Core" -Location $SettingsObject.automation.location -Name $SettingsObject.automation.name

			if ( $false -eq $SettingsObject.automation.managedIdentity.enabled ) {

				Write-Verbose "Managed Identity will not be created..."
				$identity = "None"
			}
			else {

				Write-Verbose "Managed Identity be created..."
				$identity = "SystemAssigned"
			}

			# Create Automation account
			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Core" -Location $SettingsObject.automation.location -Name "New-CmAzCoreAutomation"

			Write-Verbose "Deploying automation account..."
			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-ResourceGroupName $resourceGroupName `
				-TemplateFile "$PSScriptRoot\New-CmAzCoreAutomation.json" `
				-TemplateParameterObject @{
					AutomationAccountName = $automationAccountName
					Location              = $SettingsObject.automation.location
					AutomationService     = $SettingsObject.service.publish.automation
					WorkspaceObject       = $workspace
					Identity              = $identity
				}


			$principle = (Get-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccountName).Identity.PrincipalId

			if ($principle) {

				Write-Verbose "Current environment supports assigning role to managed identity..."

				if ( $SettingsObject.automation.managedIdentity.role -ne "None" ) {

					if ( !$SettingsObject.automation.managedIdentity.scope ) {
						$SettingsObject.automation.managedIdentity.scope = "/subscriptions/$((Get-AzContext).Subscription.Id)"
					}

					$SettingsObject.automation.managedIdentity.role ??= "Contributor"

					Write-Verbose "Assigning role: $($SettingsObject.automation.managedIdentity.role) for principle $principle..."
					New-AzRoleAssignment `
						-ObjectId $principle `
						-Scope $SettingsObject.automation.managedIdentity.scope `
						-RoleDefinitionName $SettingsObject.automation.managedIdentity.role `
						-ErrorAction Ignore
				}
			}
			else {
				Write-Verbose "Current environment does not support assigning role to managed identity. Please assign role explicitly!"
			}


			if ($repoUrl) {
				try {
					if ($repoType -eq "tvfc") {
						New-AzAutomationSourceControl -Name "$repoType" -RepoUrl $repoUrl -SourceType VsoTfvc -AccessToken $personalAccessToken -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -FolderPath $folderPath
					}
					elseif ($repoType -eq "github") {
						New-AzAutomationSourceControl -Name "$repoType" -RepoUrl $repoUrl -SourceType GitHub -AccessToken $personalAccessToken -Branch $branch -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -FolderPath $folderPath
					}
					elseif ($repoType -eq "git") {
						New-AzAutomationSourceControl -Name "$repoType" -RepoUrl $repoUrl -SourceType VsoGit -AccessToken $personalAccessToken -Branch $branch -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -FolderPath $folderPath
					}
					else {
						Write-Warning "Please choose correct repository - tvfc | git | github." -ErrorAction Continue
					}

					Write-Verbose "$repoType Added..."

					# Attempt autosync
					try {
						Update-AzAutomationSourceControl -AutomationAccountName $automationAccountName -Name "$repoType" -AutoSync $true -ResourceGroupName $resourceGroupName
					}
					catch {
						$_.ToString() | Write-Verbose
						Write-Warning "AutoSync couldn't be enabled. Make sure you have 'Read, query, manage' permissions" -ErrorAction Continue -WarningAction Continue
					}

					# Start first sync job
					Start-AzAutomationSourceControlSyncJob -AutomationAccountName $automationAccountName -Name "$repoType" -ResourceGroupName $resourceGroupName
					Write-Verbose "First Sync initiated..."
				}
				catch {
					Write-Verbose "Repository couldn't be added..."
					Write-Verbose "$PSitem..."
				}
			}

			if ($SettingsObject.automation.privateEndpoints) {

				$endpointName = "automation"

				Write-Verbose "Building private endpoints..."
				Build-PrivateEndpoints -SettingsObject $SettingsObject -LookupProperty $endpointName -ResourceName $endpointName
			}

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupName

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}
}
