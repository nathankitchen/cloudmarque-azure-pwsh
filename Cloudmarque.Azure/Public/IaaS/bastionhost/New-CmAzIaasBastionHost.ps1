function New-CmAzIaasBastionHost {
	<#
		.Synopsis
		Creates Bastion host

		.Description
		Completes following:
			* This script creates Bastion hosts in resource group.
			* Creates 'AzureBastionSubnet' if not already exists.
			* Azure Bastion provisions directly in your Azure Virtual Network, providing Bastion host or jump server as-a-service and integrated connectivity to all virtual machines in your virtual networking using RDP/SSH directly from and through your browser and the Azure portal experience.

		.Parameter SettingsFile
		File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		Object containing the configuration values required to run this cmdlet.

		.Component
		IaaS

		.Example
		New-CmAzIaasBastionHost -settingsFile "BastionHostyml"

		.Example
		New-CmAzIaasBastionHost -settingsObject $BastionHostSettings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create Bastion Host in resource group")) {

			if ($SettingsFile -and -not $SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (-not $SettingsFile -and -not $SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			$env:location = $SettingsObject.Location
			$env:permanentPSScriptRoot = $PSScriptRoot
			$resourceGroupName = (Get-CmAzService -Service $SettingsObject.ResourceGroupTag -isResourceGroup -ThrowIfUnavailable).ResourceGroupName
			$env:rootfolder = (Get-cmAzContext).projectroot

			Write-Verbose "Fetching workspace.."

			if (!$SettingsObject.WorkspaceTag) {
				$bastionWorkspace = @{"Name" = ""; "ResourceId" = ""; "Location" = "" }
			}
			else {
				Write-Verbose "Fetching workspace.."
				$workspace = Get-CmAzService -Service $SettingsObject.WorkspaceTag
				$workspace = Get-AzOperationalInsightsWorkspace -Name $workspace.Name -ResourceGroupName $workspace.ResourceGroupName
				$bastionWorkspace = @{"Name" = $workspace.Name; "ResourceId" = $workspace.ResourceId; "Location" = $workspace.location }
			}

			$SettingsObject.BastionHosts | ForEach-Object -parallel {
				$_.VnetName = (Get-CmAzService -Service $_.vnetTag).name
				$VnetObject = Get-AzVirtualNetwork -Name $_.VnetName

				$_.BastionPublicIPName = Get-CmAzResourceName -Resource "PublicIPAddress" `
					-Architecture "IaaS" `
					-Region $env:location `
					-Name $_.BastionHostName

				$_.BastionHostName = Get-CmAzResourceName -Resource "BastionHost" `
					-Architecture "IaaS" `
					-Region $env:location `
					-Name $_.BastionHostName

				Write-Verbose "Checking if subnet 'AzureBastionSubnet' exists in Vnet"
				$bastionHostSubnet = Get-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" `
					-VirtualNetwork $VnetObject -ErrorAction SilentlyContinue

				if (!$bastionHostSubnet) {
					Write-Verbose "AzureBastionSubnet not found!"
					if (!$_.BastionHostSubnetPrefix) {
						Write-Error "Subnet prefix for AzureBastionSubnet subnet not found. Please provide cidr"  -targetobject $_.BastionHostSubnetPrefix
					}
				}
				else {
					Write-Verbose "'AzureBastionSubnet' subnet Found!"
					$_.BastionHostSubnetPrefix = ""
				}
			}
			New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
				-TemplateFile "$env:permanentPSScriptRoot\New-CmAzIaasBastionHost.json" `
				-BastionHostObject $SettingsObject `
				-Location $env:location `
				-Workspace $bastionWorkspace `
				-Verbose
		}
		Write-Verbose "Finished!"
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}