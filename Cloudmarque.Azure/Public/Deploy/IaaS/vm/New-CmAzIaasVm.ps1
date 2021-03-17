﻿function New-CmAzIaasVm {

	<#
		.Synopsis
		 Deploys multiple virtual machines, over multiple resource groups.

		.Description
		 Completes the following:
			 * Deploys multiple virtual machines over multiple resource groups.
			 * Encrypts all os and data disks using a key encryption key from a specified keyvault.
			 * Mounts all hard drives set up in the vms.
			 * Enables azure monitor and links all vms to the core log analytics workspace.
			 * Automatically accepts terms for using custom images.

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

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

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
		[SecureString]$LocalAdminPassword,
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Virtual Machines")) {

			[Hashtable]$keyVaultDetails = $null

			$keyVaultService = Get-CmAzService -Service $SettingsObject.service.dependencies.keyvault -ThrowIfUnavailable -ThrowIfMultiple

			$keyVault = Get-AzKeyVault -Name $keyVaultService.name

			if (!$keyVault) {
				Write-Error "Cannot find key vault resource, ensure the provided tag is set on a keyvault." -Category InvalidArgument -CategoryTargetName "KeyVault.Tag"
			}
			else {
				Write-Verbose "Keyvault found.."
			}

			$keyEncryptionKey = Get-AzKeyVaultKey -VaultName $keyVault.vaultName -Name $SettingsObject.diskEncryptionKey

			if (!$keyEncryptionKey) {
				Write-Error "Cannot find key encryption key in keyvault." -Category InvalidArgument -CategoryTargetName "KeyVault.DiskEncryptionKey"
			}
			else {
				Write-Verbose "Encryption key found.."
			}

			$keyVaultDetails = @{
				KeyEncryptionKeyUrl = $keyEncryptionKey.id
				ResourceId          = $keyVault.resourceId;
				VaultUri            = $keyVault.vaultUri
			}

			$automationAccount = Get-CmAzService -Service $SettingsObject.service.dependencies.automation -ThrowIfUnavailable -ThrowIfMultiple

			$automationAccountRegistration = Get-AzAutomationRegistrationInfo `
				-ResourceGroupName $automationAccount.resourceGroupName `
				-AutomationAccountName $automationAccount.name  `
				-ErrorAction SilentlyContinue

			if (!$automationAccountRegistration) {
				Write-Error "Cannot find automation registration details." -Category InvalidArgument -CategoryTargetName "AutomationAccountTag"
			}
			else {
				Write-Verbose "Automation Registration details found.."
			}

			$automationAccount.registrationUrl = $automationAccountRegistration.endpoint
			$automationAccount.primaryKey = $automationAccountRegistration.primaryKey
			$automationAccount.nodeConfigurationName = $SettingsObject.desiredConfigName

			$workspace = Get-CmAzService -Service $SettingsObject.service.dependencies.workspace -ThrowIfUnavailable -ThrowIfMultiple

			$allResourceGroups = @()
			$allVirtualMachines = @()
			$allProximityPlacementGroups = @()
			$allAvailabilitySets = @()

			$daysOfWeek = [DayOfWeek].GetEnumNames()

			$localConfigs = Get-CmAzSettingsFile -Path "$PSScriptRoot/localConfigs.yml"

			foreach ($resourceGroup in $SettingsObject.groups) {

				if (!$resourceGroup.location) {
					$resourceGroup.location = $SettingsObject.location
				}

				$resourceGroup.name = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "IaaS" -Region $resourceGroup.location -Name $resourceGroup.name

				if ($resourceGroup.proximityPlacementGroups) {

					foreach ($placementGroup in $resourceGroup.proximityPlacementGroups) {
						$placementGroup.location ??= $resourceGroup.location

						$placementGroup.generatedName = Get-CmAzResourceName -Resource "ProximityPlacementGroup" -Architecture "IaaS" -Region $placementGroup.location -Name $placementGroup.name
						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "ProximityPlacementGroup" -ResourceServiceContainer $placementGroup

						$placementGroup.resourceGroupName = $resourceGroup.name

						$allProximityPlacementGroups += $placementGroup
					}
				}
				else {

					$placementGroup = @{
						resourceGroupName = $resourceGroup.name
						generatedName     = "none";
						location          = "uksouth";
						service           = @{
							publish = @{
								proximityPlacementGroup = "none"
							}
						}
					}

					$allProximityPlacementGroups += $placementGroup
				}

				if ($resourceGroup.availabilitySets) {

					foreach ($set in $resourceGroup.availabilitySets) {
						$set.generatedName = Get-CmAzResourceName -Resource "AvailabilitySet" -Architecture "IaaS" -Region $set.location -Name $set.name

						if ($set.proximityPlacementGroup) {
							$set.proximityPlacementGroup = ($resourceGroup.proximityPlacementGroups | Where-Object { $_.name -eq $set.proximityPlacementGroup }).generatedName

							if (!$set.proximityPlacementGroup) {
								Write-Error "Proximity group not found in settings..."
							}
						}
						else {
							$set.proximityPlacementGroup = ""
						}

						$set.location ??= $resourceGroup.location
						$set.resourceGroupName = $resourceGroup.name

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "availabilitySet" -ResourceServiceContainer $set

						$allAvailabilitySets += $set
					}
				}
				else {
					$set = @{
						resourceGroupName         = $resourceGroup.name
						generatedName             = "none";
						location                  = "uksouth";
						platformFaultDomainCount  = "2";
						platformUpdateDomainCount = "2";
						sku                       = "aligned"
						service                   = @{
							publish = @{
								proximityPlacementGroup = "none"
							}
						}
					}

					$allAvailabilitySets += $set
				}

				foreach ($virtualMachine in $resourceGroup.virtualMachines) {

					if ($virtualMachine.zone -And $virtualMachine.availabilitySet) {
						Write-Error "Virtual Machines with both Availability Zones and Availability Sets are not supported by Azure..." -Category InvalidArgument -CategoryTargetName "VirtualMachines"
					}

					if (!$virtualMachine.location) {
						$virtualMachine.location = $resourceGroup.location
					}

					if (!$virtualMachine.plan) {
						$virtualMachine.plan = ""
					}
					else {

						Write-Verbose "Using custom image: $($virtualMachine.plan.publisher) $($virtualMachine.plan.product)"
						$terms = Get-AzMarketplaceTerms -Publisher $virtualMachine.plan.publisher -Product $virtualMachine.plan.product -Name $virtualMachine.plan.name

						if (!$terms.Accepted) {

							Write-Warning "Image usage terms will be accepted automatically.."
							Set-AzMarketplaceTerms -Publisher $virtualMachine.plan.publisher -Product $virtualMachine.plan.product -Name $virtualMachine.plan.name -Terms $terms -Accept
						}
					}

					$virtualMachine.resourceGroupName = $resourceGroup.name

					Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "vnet" -ResourceServiceContainer $virtualMachine.networking -IsDependency

					$virtualNetwork = Get-CmAzService -Service $virtualMachine.networking.service.dependencies.vnet -Region $virtualMachine.location -ThrowIfUnavailable -ThrowIfMultiple

					$virtualMachine.networking.virtualNetworkId = $virtualNetwork.resourceId

					Write-Verbose "Generating standardised resource names..."
					$virtualMachine.computerName = Get-CmAzResourceName -Resource "ComputerName" -Architecture "Core" -Region $virtualMachine.location -Name $virtualMachine.name -MaxLength 15
					$virtualMachine.fullName = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "IaaS" -Region $virtualMachine.location -Name $virtualMachine.name
					$virtualMachine.nicName = Get-CmAzResourceName -Resource "NetworkInterfaceCard" -Architecture "IaaS" -Region $virtualMachine.location -Name $virtualMachine.fullName
					$virtualMachine.osDisk.Name = Get-CmAzResourceName -Resource "OSDisk" -Architecture "IaaS" -Region $virtualMachine.location -Name $virtualMachine.fullName

					$virtualMachine.osDisk.caching ??= "None"
					$virtualMachine.zone ??= "none"

					if ($virtualMachine.timeZone) {

						Write-Verbose "TimeZone settings found."
						$virtualMachine.timeZone = $localConfigs.timeZones.contains($virtualMachine.timeZone) ? $virtualMachine.timeZone : (Write-Error "Please provide valid Windows timezone format...")
					}
					else {
						$virtualMachine.timeZone = "UTC"
					}

					if ($virtualMachine.antimalware) {

						Write-Verbose "Antimalware settings found."
						$virtualMachine.antimalware.exclusions = @{
							paths      = $virtualMachine.antimalware.exclusions.paths -join (';');
							extensions = $virtualMachine.antimalware.exclusions.extensions -join (';');
							processes  = $virtualMachine.antimalware.exclusions.processes -join (';')
						}

						if ($virtualMachine.antimalware.schedule) {
							$virtualMachine.antimalware.schedule.scanType ??= "Quick"
							$virtualMachine.antimalware.schedule.day = $localConfigs.days.$($virtualMachine.antimalware.schedule.day)
							$virtualMachine.antimalware.schedule.time = $virtualMachine.antimalware.schedule.time.toString()
							$virtualMachine.antimalware.schedule.isEnabled = "true"
						}
						else {
							$virtualMachine.antimalware.schedule = @{ isEnabled = "false" }
						}

						$virtualMachine.antimalware.realtimeProtectionEnabled = $virtualMachine.antimalware.realtimeProtectionEnabled ? "true" : "false"
					}
					else {
						$virtualMachine.antimalware = @{
							enable = $false
							exclusions = @{
								Path       = "";
								Extensions = "";
								Processes  = "";
							}
							schedule = @{ isEnabled = "false" }
						}
					}

					if ($virtualMachine.availabilitySet) {

						$virtualMachine.availabilitySet = ($resourceGroup.availabilitySets | Where-Object { $_.name -eq $virtualMachine.availabilitySet }).generatedName

						if (!$virtualMachine.availabilitySet) {
							Write-Error "Availability Set not found in settings..."
						}
					}
					else {
						$virtualMachine.availabilitySet = ""
					}

					$virtualMachine.vulnerabilityScan ??= $false

					Write-Verbose "Building data disks..."

					if ($virtualMachine.dataDisks) {

						for ($i = 0; $i -lt $virtualMachine.dataDisks.Count; $i++) {
							$virtualMachine.dataDisks[$i].name = Get-CmAzResourceName -Resource "DataDisk" -Architecture "IaaS" -Region $virtualMachine.location -Name "$($virtualMachine.name)$($i + 1)";
							$virtualMachine.dataDisks[$i].Lun = $i + 1;
							$virtualMachine.dataDisks[$i].CreateOption = "Empty";
							$virtualMachine.dataDisks[$i].caching ??= "None"
						}
					}
					else {
						$virtualMachine.dataDisks = @()
					}

					Write-Verbose "Building update tag.."
					if ($virtualMachine.updateGroup -and $virtualMachine.updateFrequency) {

						$scheduleSettings = Get-CmAzSettingsFile -Path "$PSScriptRoot/scheduleTypes.yml"

						$inValidScheduleSettings = !$scheduleSettings -or !$scheduleSettings.updateGroups[$virtualMachine.updateGroup] -or	(!$scheduleSettings.updateFrequencies[$virtualMachine.updateFrequency] -and $daysOfWeek -notcontains $virtualMachine.updateFrequency)

						if ($inValidScheduleSettings) {
							Write-Error "No valid schedule settings." -Category ObjectNotFound -CategoryTargetName "scheduleTypeSettingsObject"
						}

						$virtualMachine.updateTag = "$($virtualMachine.updateGroup)-$($virtualMachine.updateFrequency)".ToLower()
					}
					else {
						$virtualMachine.updateTag = ""
					}

					Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "vm" -ResourceServiceContainer $virtualMachine
					Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "nic" -ResourceServiceContainer $virtualMachine
				}

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "resourceGroup" -ResourceServiceContainer $resourceGroup

				$allResourceGroups += $resourceGroup;
				$allVirtualMachines += $resourceGroup.virtualMachines
			}

			Write-Verbose "Deploying virtual machines..."

			if (!$allVirtualMachines) {
				Write-Verbose "No valid virtual machines available for deployment..."
			}
			else {

				$deploymentNameRgs = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $SettingsObject.location -Name "New-CmAzIaasVm-Rgs"

				New-AzDeployment `
					-Name $deploymentNameRgs `
					-TemplateFile "$PSScriptRoot\New-CmAzIaasVm.ResourceGroups.json" `
					-ResourceGroups $allResourceGroups `
					-Location $SettingsObject.location

				# Cross resource group deployments for VMs appear to still to require the use of New-AzResourceGroupDeployment, instead of subscription level deployment
				# through New-AzDeployment, which doesn't seem right.
				# Deploying the same template through New-AzDeployment triggers a BadRequest: InvalidRequestFormat error.

				$credentials = @{
					"LocalAdminUsername" = ConvertFrom-SecureString $LocalAdminUsername -AsPlainText;
					"LocalAdminPassword" = ConvertFrom-SecureString $LocalAdminPassword -AsPlainText;
				}

				$deploymentNameVm = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $SettingsObject.location -Name "New-CmAzIaasVm"

				New-AzResourceGroupDeployment `
					-Name $deploymentNameVm  `
					-TemplateFile "$PSScriptRoot\New-CmAzIaasVm.json" `
					-ResourceGroupName $allResourceGroups[0].name `
					-Credentials $credentials `
					-VirtualMachines $allVirtualMachines `
					-ProximityPlacementGroups $allProximityPlacementGroups `
					-AvailabilitySets $allAvailabilitySets `
					-WorkspaceId $workspace.resourceId `
					-KeyVault $keyVaultDetails `
					-AutomationAccount $automationAccount `
					-Force
			}

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $allResourceGroups.name

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}