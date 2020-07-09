function New-CmAzIaasVm {

	<#
		.Synopsis
		 Deploys multiple virtual machines, over multiple resource groups.

		.Description
		 Completes the following:
			 * Deploys multiple virtual machines over multiple resource groups.
			 * Encrypts all os and data disks using a key encryption key from a specified keyvault.
			 * Mounts all hard drives set up in the vms.
			 * Enables azure monitor and links all vms to the core log analytics workspace.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter LocalAdminUsername
		 Local admin username for deployed vms, max length 20 characters.

		.Parameter LocalAdminPassword
		 Local admin passwords for deployed vms, requires three of the following character types:
			* Uppercase
			* Lowercase
			* Numeric
			* Special

		.Component
		 IaaS

		.Example
		 New-CmAzIaasCompute -SettingsFile "c:/directory/settingsFile.yml" -LocalAdminUsername "username" -LocalAdminPassword "password"

		.Example
	 	 New-CmAzIaasCompute -SettingsObject $settings -LocalAdminUsername "username" -LocalAdminPassword "password"
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[parameter(Mandatory = $true)]
		[SecureString]$LocalAdminUsername,
		[parameter(Mandatory = $true)]
		[SecureString]$LocalAdminPassword
	)

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Virtual Machines")) {

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			[Hashtable]$keyVaultDetails = $null

			if (!$SettingsObject.Location) {
				Write-Error "Please provide a valid location." -Category InvalidArgument -CategoryTargetName "Location"
			}

			if (!$SettingsObject.KeyVault.Tag) {
				Write-Error "Please provide a valid key vault tag." -Category InvalidArgument -CategoryTargetName "KeyVault.Tag"
			}

			$keyVaultService = Get-CmAzService -Service $SettingsObject.KeyVault.Tag -Region $SettingsObject.Location -ThrowIfUnavailable

			$keyVault = Get-AzKeyVault -Name $keyVaultService.Name

			if (!$keyVault) {
				Write-Error "Cannot find key vault resource, ensure the provided tag is set on a keyvault." -Category InvalidArgument -CategoryTargetName "KeyVault.Tag"
			}

			$keyEncryptionKey = Get-AzKeyVaultKey -VaultName $keyVault.VaultName -Name $SettingsObject.KeyVault.DiskEncryptionKey

			if (!$keyEncryptionKey) {
				Write-Error "Cannot find key encryption key in keyvault." -Category InvalidArgument -CategoryTargetName "KeyVault.DiskEncryptionKey"
			}

			$keyVaultDetails = @{
				KeyEncryptionKeyUrl = $keyEncryptionKey.Id
				ResourceId          = $keyVault.ResourceId;
				VaultUri            = $keyVault.VaultUri
			}

			$automationAccount = Get-CmAzService -Service $SettingsObject.AutomationAccountTag -Region $SettingsObject.Location -ThrowIfUnavailable

			$automationAccountRegistration = Get-AzAutomationRegistrationInfo -ResourceGroupName $automationAccount.ResourceGroupName  `
				-AutomationAccountName $automationAccount.Name  `
				-ErrorAction SilentlyContinue

			if (!$automationAccountRegistration) {
				Write-Error "Cannot find automation registration details." -Category InvalidArgument -CategoryTargetName "AutomationAccountTag"
			}

			$automationAccount.registrationUrl = $automationAccountRegistration.endpoint
			$automationAccount.primaryKey = $automationAccountRegistration.primaryKey
			$automationAccount.nodeConfigurationName = $SettingsObject.desiredConfigName

			$workspace = Get-CmAzService -Service "core.logging.loganalytics" -Region $SettingsObject.location -ThrowIfUnavailable

			$allResourceGroupNames = @()
			$allVirtualMachines = @()
			$virtualNetworks = @{ }

			$daysOfWeek = [DayOfWeek].GetEnumNames()

			foreach ($resourceGroup in $SettingsObject.Groups) {

				if (!$resourceGroup.Name) {
					Write-Error "Please provide a valid resource group name." -Category InvalidArgument -CategoryTargetName "Groups.VirtualMachines.VirtualNetworkTag"
				}

				$resourceGroup.Name = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "IaaS" -Region $SettingsObject.Location -Name $resourceGroup.Name

				foreach ($virtualMachine in $resourceGroup.VirtualMachines) {

					$virtualMachine.ResourceGroupName = $resourceGroup.Name

					if (!$virtualMachine.Networking.VirtualNetworkTag) {
						Write-Error "Please provide a valid virtual network tag for vm $($virtualMachine.Name)." -Category InvalidArgument -CategoryTargetName "Groups.VirtualMachines.VirtualNetworkTag"
					}

					if (!$virtualNetworks[$virtualMachine.Networking.VirtualNetworkTag]) {

						$virtualNetwork = Get-CmAzService -Service $virtualMachine.Networking.VirtualNetworkTag -Region $SettingsObject.Location -ThrowIfUnavailable

						$virtualNetworks[$virtualMachine.Networking.VirtualNetworkTag] = $virtualNetwork.ResourceId
					}

					$virtualMachine.Networking.VirtualNetworkId = $virtualNetworks[$virtualMachine.Networking.VirtualNetworkTag]

					Write-Verbose "Generating standardised resource names..."
					$virtualMachine.ComputerName = Get-CmAzResourceName -Resource "ComputerName" -Architecture "Core" -Region $SettingsObject.Location -Name $virtualMachine.Name -MaxLength 15
					$virtualMachine.NicName = Get-CmAzResourceName -Resource "NetworkInterfaceCard" -Architecture "IaaS" -Region $SettingsObject.Location -Name $virtualMachine.Name
					$virtualMachine.OSDisk.Name = Get-CmAzResourceName -Resource "OSDisk" -Architecture "IaaS" -Region $SettingsObject.Location -Name $virtualMachine.Name
					$virtualMachine.FullName = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "IaaS" -Region $SettingsObject.Location -Name $virtualMachine.Name

					Write-Verbose "Building data disks..."
					$virtualMachine.DataDisks = @()

					for ($i = 0; $i -lt $virtualMachine.DataDiskSizes.Count; $i++) {

						$virtualMachine.DataDisks += @{
							"Name"         = Get-CmAzResourceName -Resource "DataDisk" -Architecture "IaaS" -Region $SettingsObject.Location -Name "$($virtualMachine.Name)$($i + 1)";
							"Lun"          = $i + 1;
							"CreateOption" = "Empty";
							"DiskSizeGB"   = $virtualMachine.DataDiskSizes[$i]
						}
					}

					Write-Verbose "Building update tag.."
					if ($virtualMachine.updateGroup -and $virtualMachine.updateFrequency) {

						$scheduleSettings = Get-CmAzSettingsFile -Path "$PSScriptRoot/scheduletypes.yml"

						$inValidScheduleSettings = 
							!$scheduleSettings -or
							!$scheduleSettings.UpdateGroups[$virtualMachine.updateGroup] -or 
							(!$scheduleSettings.UpdateFrequencies[$virtualMachine.updateFrequency] -and $daysOfWeek -notcontains $virtualMachine.updateFrequency)
							
						if ($inValidScheduleSettings) {
							Write-Error "No valid schedule settings." -Category ObjectNotFound -CategoryTargetName "scheduleTypeSettingsObject"
						}

						$virtualMachine.updateTag = @{ "cm-update" = "$($virtualMachine.updateGroup)-$($virtualMachine.updateFrequency)" }
					}
				}

				$allResourceGroupNames += $resourceGroup.Name
				$allVirtualMachines += $resourceGroup.VirtualMachines
			}

			Write-Verbose "Deploying virtual machines..."

			if (!$allVirtualMachines) {
				Write-Verbose "No valid virtual machines available for deployment..."
			}
			else {
				New-AzDeployment `
					-TemplateFile "$PSScriptRoot\New-CmAzIaasVm.ResourceGroups.json" `
					-LocationFromTemplate $SettingsObject.Location `
					-Location $SettingsObject.Location `
					-ResourceGroupNames $allResourceGroupNames

				# Cross resource group deployments for VMs appear to still to require the use of New-AzResourceGroupDeployment, instead of subscription level deployment
				# through New-AzDeployment, which doesn't seem right.
				# Deploying the same template through New-AzDeployment triggers a BadRequest: InvalidRequestFormat error.

				New-AzResourceGroupDeployment `
					-TemplateFile "$PSScriptRoot\New-CmAzIaasVm.json" `
					-ResourceGroupName $allResourceGroupNames[0] `
					-LocalAdminUsername $LocalAdminUsername  `
					-LocalAdminPassword $LocalAdminPassword `
					-VirtualMachines $allVirtualMachines `
					-WorkspaceId $workspace.ResourceId `
					-KeyVault $keyVaultDetails `
					-AutomationAccount $automationAccount
			}

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}