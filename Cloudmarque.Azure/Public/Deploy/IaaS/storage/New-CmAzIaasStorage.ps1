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
		 Parmeter to specify if the cmdlet should handle its own tagging.

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

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Storage Account/s.")) {

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

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
					default {
						Write-Error "Only premium or standard account type allowed."
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
							"publicAccess" = "none"
						}
					)
				}
				else {
					Write-Verbose "$($_.storageAccountName): Blob configuration found."
					$_.blobContainer | ForEach-Object {
						if (!$_.publicAccess) {
							$_.publicAccess = "none"
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

				$_.storageAccountName = Get-CmAzResourceName -Resource "Storageaccount" -Architecture "IaaS" -Region $_.location -Name $_.storageAccountName
			}

			Write-Verbose "Settings verified successfully. Initiating deployment."

			if ($SettingsObject.service.dependencies.resourceGroup) {
				$resourceGroup = Get-CmAzService -Service $SettingsObject.service.dependencies.resourceGroup -IsResourceGroup -ThrowIfUnavailable -ThrowIfMultiple
				$SettingsObject.location = $resourceGroup.Location
			}

			if (!$resourceGroup -and $SettingsObject.resourceGroupName) {

				Write-Verbose "ResourceGroup wasn't found with tag. New resource group will be created with provided name."
				$resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Name $SettingsObject.resourceGroupName -Region $SettingsObject.Location
				$resourceGroupExists = Get-AzResourceGroup -Name $SettingsObject.resourceGroupName -ErrorAction SilentlyContinue

				if (!$resourceGroupExists) {

					if ($SettingsObject.service.publish.resourceGroup) {
						$resourceGroup = New-AzResourceGroup -ResourceGroupName $resourceGroupName -Tag @{"cm-service" = $SettingsObject.service.publish.resourceGroup } -Location $SettingsObject.Location -Force
						Write-Verbose "Resource Group created: $($resourceGroup.ResourceGroupName)"

						$resourceGroupsToSet = $resourceGroup.ResourceGroupName
					}
					else {
						Write-Verbose "Resource group doesn't exists and is required to be created. Please provide resource Group service tag to publish"
					}
				}
				else {
					Write-Error "Resource Group with provided name already exists.`nPlease provfide appropriate service tag for existing resource group or provide unique name to create new."
				}

			}
			elseif (!$resourceGroup -and !$SettingsObject.resourceGroupName) {
				Write-Error "Please provide appropriate service tag for existing resource group or provide unique name to create new."
			}

			New-AzResourceGroupDeployment `
				-Name "CmAz_Storage_Master" `
				-ResourceGroupName $resourceGroup.resourceGroupName `
				-TemplateFile "$PSScriptRoot/New-CmAzIaasStorage.json" `
				-StorageSettingsArray $SettingsObject.storageAccounts `
				-Force

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

			Write-Verbose "Finished."
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}