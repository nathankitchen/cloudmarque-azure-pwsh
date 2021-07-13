function New-CmAzIaasWvd {

	<#
		.Synopsis
		 Able to deploy multiple Windows Virtual Desktop environments, over many resource groups.

		.Description
		 Completes the following:
			 * Deploys the Resource Group\s.
			 * Deploys Windows Virtual Desktop Hostpool\s.
			 * Deploys Windows Virtual Desktop Application Group\s.
			 * Deploys Windows Virtual Desktop workspace\s.
			 * Deploys the Availability Set\s ready for any hosts.
			 * Additionally, able to deploy Windows Virtual Desktop host virtual machine\s, if any are requested.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 IaaS

		.Example
   		 New-CmAzIaaSWVD -SettingsFile "c:/directory/SettingsFile.yml"

		.Example
	 	 New-CmAzIaaSWVD -SettingsObject $SettingsObject
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "stop"

	try {

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Windows Virtual Desktop environment.")) {

			Write-Verbose "Beginning WVD infrastructure object creation."
			foreach ($wvdEnvironment in $SettingsObject.wvdEnvironments) {

				$wvdEnvironment.resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "IaaS" -Location $wvdEnvironment.wvdEnvironmentLocation -Name $wvdEnvironment.wvdEnvironmentName
				Write-Verbose "Generated resource group name: $($wvdEnvironment.resourceGroupName)"

				$wvdEnvironment.workspaceName = Get-CmAzResourceName -Resource "WVDWorkspace" -Architecture "IaaS" -Location $wvdEnvironment.wvdEnvironmentLocation -Name $wvdEnvironment.wvdEnvironmentName
				Write-Verbose "Generated Workspace name: $($wvdEnvironment.workspaceName)"

				$wvdEnvironment.hostpool.hostpoolName = Get-CmAzResourceName -Resource "WVDHostpool" -Architecture "IaaS" -Location $wvdEnvironment.wvdEnvironmentLocation -Name $wvdEnvironment.wvdEnvironmentName
				Write-Verbose "Generated Hostpool name: $($wvdEnvironment.hostpool.hostpoolName)"

				$wvdEnvironment.desktopGroupName = Get-CmAzResourceName -Resource "WVDDesktopGroup" -Architecture "IaaS" -Location $wvdEnvironment.wvdEnvironmentLocation -Name $wvdEnvironment.wvdEnvironmentName
				Write-Verbose "Generated Desktop Application Group name: $($wvdEnvironment.desktopGroupName)"

				if (!$wvdEnvironment.hostVm.hostVmLocation) {
					$wvdEnvironment.hostVm.hostVmLocation = $wvdEnvironment.wvdEnvironmentLocation
					Write-Verbose "Setting virtual machine location to: $($wvdEnvironment.wvdEnvironmentLocation)"
				}

				if (!$wvdEnvironment.hostpool.hostpoolType) {
					$wvdEnvironment.hostpool.hostpoolType = "Pooled"
					Write-Verbose "Setting host pool type to: $($wvdEnvironment.hostpool.hostpoolType)"
				}

				if (!$wvdEnvironment.hostpool.hostpoolBalancing) {
					$wvdEnvironment.hostpool.hostpoolBalancing = "DepthFirst"
					Write-Verbose "Setting host pool balance to: $($wvdEnvironment.hostpool.hostpoolBalancing)"
				}

				if (!$wvdEnvironment.hostpool.hostpoolMaxSessions) {
					$wvdEnvironment.hostpool.hostpoolMaxSessions = 10
					Write-Verbose "Setting host pool maximum sessions to: $($wvdEnvironment.hostpool.hostpoolMaxSessions)"
				}

				if (!$wvdEnvironment.hostVm.hostVmSize) {
					$wvdEnvironment.hostVm.hostVmSize = "Standard_DS4_v2"
					Write-Verbose "Setting virtual machine size to: $($wvdEnvironment.hostVm.hostVmSize)"
				}

				if (!$wvdEnvironment.hostVm.hostVmImageType) {
					$wvdEnvironment.hostVm.hostVmImageType = "Gallery"
					Write-Verbose "Setting image source to: $($wvdEnvironment.hostVm.hostVmImageType)"
				}

				if (!$wvdEnvironment.hostVm.hostVmImage) {
					$wvdEnvironment.hostVm.hostVmImage = "Windows-10"
					Write-Verbose "Setting image to: $($wvdEnvironment.hostVm.hostVmImage)"
				}

				if ($wvdEnvironment.hostpool.hostpoolType -eq "personal") {
					$wvdEnvironment.hostpool.personalDesktopAssignmentType = $wvdEnvironment.hostpool.hostpoolBalancing
					$wvdEnvironment.hostpool.hostpoolBalancing = $null
				}
				else {

					$wvdEnvironment.hostpool.personalDesktopAssignmentType = $null
				}

				switch ($wvdEnvironment.hostVm.hostVmImageType) {

					{ $_ -eq "gallery" } {

						Write-Verbose "Locating latest gallery image for: $($wvdEnvironment.hostVm.hostVmImage)"
						# Selecting the latest image is commented out and instead forcing '19h2-evd' due to issues with the WVD agent on later Windows 10 versions.
						#$latestImage = Get-AzVMImageSku -Location $wvdEnvironment.hostVm.hostVmLocation -PublisherName "MicrosoftWindowsDesktop" -Offer $wvdEnvironment.hostVm.hostVmImage | Where-Object {$_.Skus -like "*-evd" -and $_.Skus -notlike "rs*"} | Select-Object -Last 1
						$latestImage = (Get-AzVMImageSku -Location $wvdEnvironment.hostVm.hostVmLocation -PublisherName "MicrosoftWindowsDesktop" -Offer $wvdEnvironment.hostVm.hostVmImage | Where-Object {$_.Skus -eq "19h2-evd"})

						if (!$latestImage) {
							Write-Error "No valid images returned from Azure Gallery." -Category InvalidArgument -CategoryTargetName "Gallery image"
						}

						$wvdEnvironment.hostVm.hostVmLatestImageSku = $latestImage.Skus
						$wvdEnvironment.hostVm.hostVmLatestImagePublisher = $latestImage.PublisherName
						$wvdEnvironment.hostVm.hostVmLatestImageOffer = $latestImage.Offer
						$wvdEnvironment.hostVm.customImageId = ""
					}

					{ $_ -eq "customimage" } {

						Write-Verbose "Locating custom image with name: $($wvdEnvironment.hostVm.hostVmImage)."
						$wvdEnvironment.hostVm.customImageId = (Get-AzResource -Name $wvdEnvironment.hostVm.hostVmImage | Where-Object {$_.ResourceType -like "Microsoft.Compute/*images"}).ResourceId

						if (!$wvdEnvironment.hostVm.customImageId) {
							Write-Error "No custom images found with name: $($wvdEnvironment.hostVm.hostVmImage)." -Category InvalidArgument -CategoryTargetName "hostVmImage"
						}
						elseif ($wvdEnvironment.hostVm.customImageId.count -gt 1) {
							Write-Error "Multiple custom images found with name: $($wvdEnvironment.hostVm.hostVmImage)." -Category InvalidArgument -CategoryTargetName "hostVmImage"
						}

						$wvdEnvironment.hostVm.hostVmLatestImageSku = ""
						$wvdEnvironment.hostVm.hostVmLatestImagePublisher = ""
						$wvdEnvironment.hostVm.hostVmLatestImageOffer = ""
					}
				}

				$vmSize = Get-AzVMSize -Location $($wvdEnvironment.hostvm.hostVmLocation).Replace(" ","")

				$vmTemplateString = @{
					"domain" = $wvdEnvironment.hostvm.hostVmDomain
					"galleryImageOffer" = $wvdEnvironment.hostvm.hostVmImage
					"galleryImagePublisher"= $wvdEnvironment.hostvm.hostVmLatestImagePublisher
					"galleryImageSKU" = $wvdEnvironment.hostvm.hostVmLatestImageSku
					"galleryItemId" = "{0}.{1}{2}" -f $wvdEnvironment.hostvm.hostVmLatestImagePublisher, $wvdEnvironment.hostvm.hostVmImage, $wvdEnvironment.hostvm.hostVmLatestImageSku
					"imageType" = $wvdEnvironment.hostVm.hostVmImageType
					"imageUri" = $null
					"customImageId" = $wvdEnvironment.hostVm.customImageId
					"namePrefix" = $wvdEnvironment.hostvm.hostVmNamePrefix
					"osDiskType" = "StandardSSD_LRS"
					"useManagedDisks" = $true
					"vmSize" = @{
						"id" = $wvdEnvironment.hostvm.hostVmSize
						"cores" = ($vmSize | Where-Object {$_.name -eq $wvdEnvironment.hostvm.hostVmSize}).NumberOfCores
						"ram" = ($vmSize | Where-Object {$_.name -eq $wvdEnvironment.hostvm.hostVmSize}).MemoryInMB / 1Gb
					}
				}

				$wvdEnvironment.hostVm.vmTemplateString = ($vmTemplateString | ConvertTo-Json).Replace("`r`n","") -Replace (' +',"")
			}

			if (!$SettingsObject.azureDeploymentLocation) {
				$SettingsObject.azureDeploymentLocation = "UK South"
			}

			$logAnalyticsLinkName = "none"
			$logAnalyticsID = "none"

			if ($SettingsObject.logAnalyticsTag) {
				Write-Verbose "Locating log analytics using tag: $($SettingsObject.logAnalyticsTag)"
				$logAnalyticsLinkName = "WVD Log Analytics Link"
				$logAnalyticsID = (Get-CmAzService -Service $SettingsObject.logAnalyticsTag -ThrowIfUnavailable).resourceId
			}

			Write-Verbose "Deploying WVD infrastructure..."

			$deploymentNameEnv = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.azureDeploymentLocation -Name "New-CmAzWVD-Env"

			New-AzDeployment `
				-Name $deploymentNameEnv `
				-Location $SettingsObject.azureDeploymentLocation `
				-TemplateFile "$PSScriptRoot\New-CmAzWVDEnvironment.json" `
				-Environments $SettingsObject.wvdEnvironments `
				-LogAnalyticsLinkName $logAnalyticsLinkName `
				-LogAnalyticsID $logAnalyticsID

			Write-Verbose "Beginning WVD host\s object creation."
			foreach ($wvdEnvironment in $SettingsObject.wvdEnvironments) {

				Write-Verbose "Creating hostpool registration key for: $($wvdEnvironment.hostpool.hostpoolName)"
				New-AzWvdRegistrationInfo -ResourceGroupName $wvdEnvironment.resourceGroupName -HostPoolName $wvdEnvironment.hostpool.hostpoolName -ExpirationTime ((Get-Date).AddDays('1')) > $null
				$wvdEnvironment.hostpool.hostpoolToken = (Get-AzWvdRegistrationInfo -ResourceGroupName $wvdEnvironment.resourceGroupName -HostPoolName $wvdEnvironment.hostpool.hostpoolName).Token

				Write-Verbose "Locating Key Vault using service tag: $($wvdEnvironment.hostVm.hostVmKeyVaultTag)."
				$keyVaultService = Get-CmAzService -Service $wvdEnvironment.hostVm.hostVmKeyVaultTag -ThrowIfUnavailable

				$keyVault = Get-AzKeyVault -Name $keyVaultService.Name -ResourceGroupName $keyVaultService.resourceGroupName

				Write-Verbose "Key Vault ($($keyVault.VaultName)) found, acquiring secret."
				$keyVaultSecret = $keyVault | Get-AzKeyVaultSecret -Name $wvdEnvironment.hostVm.hostVmKeyVaultAdminSecret

				if (!$keyVaultSecret) {
					Write-Error "Cannot find secret in Key Vault." -Category InvalidArgument -CategoryTargetName "keyVaultSecret"
				}

				Write-Verbose "Secret acquired."
				$wvdEnvironment.hostpool.keyVaultSecretUrl = $keyVaultSecret.Id
				$wvdEnvironment.hostpool.keyVaultResourceId = $keyVault.ResourceId

				Write-Verbose "Locating network details for: $($wvdEnvironment.hostVm.hostVmVnet)"
				$networkDetails = Get-CmAzService -Service $wvdEnvironment.hostVm.hostVmVnet -ThrowIfUnavailable

				$wvdEnvironment.hostVm.hostVmVnetrg = $networkDetails.ResourceGroupName
				$wvdEnvironment.hostVm.hostVmVnetID = $networkDetails.ResourceId

				Write-Verbose "Searching for existing WVD hosts associated with: $($wvdEnvironment.hostpool.hostpoolName)"
				$CurrentVMList = Get-AzResource -ResourceGroupName $wvdEnvironment.resourceGroupName -ResourceType "Microsoft.Compute/virtualMachines"

				Write-Verbose "$($CurrentVMList.Count) WVD hosts found."
				if ($CurrentVMList) {
					Write-Verbose "Starting any non-running VMs."
					Get-AzVM -ResourceGroupName $wvdEnvironment.resourceGroupName -Status | Where-Object PowerState -NotLike "VM running" | Start-AzVM
				}

				$wvdEnvironment.hostVm.hostVmInitialNumber = 0
			}

			Write-Verbose "Deploying WVD hosts."

			$deploymentNameHosts = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.azureDeploymentLocation -Name "New-CmAzWVD-Hosts"

			New-AzDeployment `
				-Name $deploymentNameHosts `
				-Location $SettingsObject.azureDeploymentLocation `
				-TemplateFile "$PSScriptRoot\New-CmAzWVDHosts.json" `
				-Environments $SettingsObject.wvdEnvironments

			Write-Verbose "Deploying WVD host post setup."

			$deploymentNamePs = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.azureDeploymentLocation -Name "New-CmAzWVD-Ps"

			New-AzDeployment `
				-Name $deploymentNamePs `
				-Location $SettingsObject.azureDeploymentLocation `
				-TemplateFile "$PSScriptRoot\New-CmAzWVDPostSetup.json" `
				-Environments $SettingsObject.wvdEnvironments `
				-LogAnalyticsID $logAnalyticsID

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
    }
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}