function New-CmAzIaasStorage {

	<#
		.Synopsis
		 Create storage account with Blob, File share, Table and Queue

		.Description
		 Completes following:
			* Creates Storage Account from either standard and premium tier.
			* Choose redundancy.
			* Create Blob, Fileshare, Table and Queue with storage account.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Parameter OmitTags
		 Parameter to specify if the cmdlet should handle its own tagging.

		.Component
		 IaaS

		.Example
		 New-CmAzIaasStorage -SettingsFile "c:/directory/settingsFile.yml"

		.Example
	 	 New-CmAzIaasStorage -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[String]$TagSettingsFile,
		[Switch]$OmitTags
	)

	$ErrorActionPreference = "Stop"

	try {

		$commandName = $MyInvocation.MyCommand.Name

		Write-CommandStatus -CommandName $commandName

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName $commandName

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Storage Account/s.")) {

			if ($SettingsObject.service.dependencies.resourceGroup) {
				$resourceGroup = Get-CmAzService -Service $SettingsObject.service.dependencies.resourceGroup -IsResourceGroup -ThrowIfUnavailable -ThrowIfMultiple
			}

			$SettingsObject.storageAccounts | ForEach-Object {

				Write-Verbose "Building deployment object for $($_.storageAccountName)"

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "storage" -ResourceServiceContainer $_

				if (!$_.location) {
					Write-Verbose "$($_.storageAccountName): No location configuraton found. It will be set to default location $($SettingsObject.Location)"
					$_.location = $SettingsObject.location
				}

				$_.tier = $_.accountType
				$replication = $_.replication

				$_.accountType = switch ($_.accountType) {
					"premium" {
						"$($_)_LRS"
					}
					"standard" {
						if (!$replication) {
							"$($_)_LRS"
						}
						else {
							"$($_)_$replication"
						}
					}
				}

				if ($_.tier -eq "Standard") {
					$_.kind = "StorageV2"
				}

				if (!$_.kind) {
					$_.kind = "StorageV2"
				}

				if (!$_.minimumTlsVersion) {
					$_.minimumTlsVersion = "TLS1_2"
				}

				if (!$_.supportsHttpsTrafficOnly) {
					$_.supportsHttpsTrafficOnly = $true
				}

				if (!$_.allowBlobPublicAccess) {
					$_.allowBlobPublicAccess = $true
				}

				if (!$_.networkAclsBypass) {
					$_.networkAclsBypass = "AzureServices"
				}

				if (!$_.networkAclsDefaultAction) {
					$_.networkAclsDefaultAction = "Allow"
				}

				if (!$_.blobContainer) {
					$_.blobContainer = @(@{
							"name"         = "none"
							"publicAccess" = "None"
						}
					)
				}
				else {
					Write-Verbose "$($_.storageAccountName): Blob configuration found."
					$_.blobContainer | ForEach-Object {
						if (!$_.publicAccess) {
							$_.publicAccess = "None"
						}
					}
				}

				if (!$_.fileShare) {
					$_.fileShare = @(
						@{
							"name" = "none"
							"size" = 100
						})
				}
				else {
					Write-Verbose "$($_.storageAccountName): FileShare configuration found."
					$_.fileShare | ForEach-Object {
						if (!$_.size) {
							$_.size = 100
						}
					}
				}

				if (!$_.queue) {
					$_.queue = @("none")
				}
				else {
					Write-Verbose "$($_.storageAccountName): Queue configuration found."
				}

				if (!$_.table) {
					$_.table = @("none")
				}
				else {
					Write-Verbose "$($_.storageAccountName): Table configuration found."
				}

				$_.templateName = Get-CmAzResourceName -Resource "deployment" -Architecture "IaaS" -Location $_.location -Name "$commandName-$($_.storageAccountName)"
				$_.storageAccountName = Get-CmAzResourceName -Resource "Storageaccount" -Architecture "IaaS" -Location $_.location -Name $_.storageAccountName
			}

			Write-Verbose "Settings verified successfully. Initiating deployment."

			if ($SettingsObject.service.dependencies.resourceGroup) {
				$resourceGroup = Get-CmAzService -Service $SettingsObject.service.dependencies.resourceGroup -IsResourceGroup -ThrowIfUnavailable -ThrowIfMultiple
				$SettingsObject.location = $resourceGroup.location
			}
			elseif ($SettingsObject.resourceGroupName) {

				Write-Verbose "A new resource group will be created with the provided name."
				$resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "IaaS" -Name $SettingsObject.resourceGroupName -Location $SettingsObject.Location

				$resourceGroup = New-AzResourceGroup -ResourceGroupName $resourceGroupName -Tag @{"cm-service" = $SettingsObject.service.publish.resourceGroup } -Location $SettingsObject.Location -Force
				Write-Verbose "Resource Group created: $($resourceGroup.ResourceGroupName)"

				$resourceGroupsToSet = $resourceGroup.ResourceGroupName
			}
			else {
				Write-Error "Please provide appropriate service tag for existing resource group or provide unique name to create new."
			}

			Write-Verbose "Deploying Storage Accounts..."

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Location $SettingsObject.Location -Architecture "IaaS" -Name "New-CmAzIaasStorage"

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-ResourceGroupName $resourceGroup.resourceGroupName `
				-TemplateFile "$PSScriptRoot/New-CmAzIaasStorage.json" `
				-StorageSettingsArray $SettingsObject.storageAccounts `
				-Force

			if ($SettingsObject.storageAccounts.privateEndpoints) {

				Write-Verbose "Building private endpoints..."
				Build-PrivateEndpoints -SettingsObject $SettingsObject -LookupProperty "storageAccounts" -ResourceName "storage" -NameProperty "storageAccountName"
			}

			if ($OmitTags) {
				Write-Warning "Storage tagging omitted.."
			}
			else {
				# Will run only if new resource Group is created
				Write-Verbose "Tagging Initiated.."
				Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupsToSet

				$resourcesToSet += $SettingsObject.storageAccounts.storageAccountName
				Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $resourcesToSet
			}

			Write-CommandStatus -CommandName $commandName -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}