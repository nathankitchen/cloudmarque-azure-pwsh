<#
	.Synopsis
	Creates Bastion host

	.Description
	Completes following:
	* This script creates Bastion hosts in resource group.
	* Creates 'AzureBastionSubnet' if not already exists.
	* Azure Bastion provisions directly in your Azure Virtual Network,providing Bastion host or jump server as-a-service and integrated connectivity to all virtual machines in your virtual networking using RDP/SSH directly from and through your browser and the Azure portal experience.

	.Parameter SettingsFile
	File path for the settings file to be converted into a settings object.

	.Parameter SettingsObject
	Object containing the configuration values required to run this cmdlet.

	.Component IaaS

	.Example
	New-CmAzIaasBastionHost -settingsFile "BastionHostyml"
	New-CmAzIaasBastionHost -settingsObject $BastionHostSettings
#>
function New-CmAzIaasBastionHost {
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

			$env:Location = $SettingsObject.Location
			$env:PermanentPSScriptRoot = $PSScriptRoot
			$ResourceGroupName = (Get-CmAzService -Service $SettingsObject.resourceGroupTag -isResourceGroup -ThrowIfUnavailable).ResourceGroupName
			$env:Rootfolder = (Get-cmAzContext).projectroot

			Write-Verbose "$((get-date).TimeOfDay.ToString()) - Fetching workspace.."
			$workspace = Get-CmAzService -Service $SettingsObject.workspaceTag
			$workspace = Get-AzOperationalInsightsWorkspace -Name $workspace.name -ResourceGroupName $workspace.ResourceGroupName

			if (!$workspace) {
				$workspace.CustomerId = "none"
			}

			$SettingsObject.BastionHosts | ForEach-Object {

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Trying to set context"
				Set-CmAzContext -Projectroot $env:Rootfolder
				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Context set"

				$_.VnetName = (Get-CmAzService -Service $_.vnetTag).name
				$VnetObject = Get-AzVirtualNetwork -Name $_.VnetName

				$_.BastionPublicIPName = Get-CmAzResourceName -Resource "PublicIPAddress" `
					-Architecture "IaaS" `
					-Region $env:Location `
					-Name $_.BastionHostName

				$_.BastionHostName = Get-CmAzResourceName -Resource "BastionHost" `
					-Architecture "IaaS" `
					-Region $env:Location `
					-Name $_.BastionHostName

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Checking if subnet 'AzureBastionSubnet' exists in Vnet"
				$_.BastionHostSubnet = Get-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" `
					-VirtualNetwork $VnetObject -ErrorAction SilentlyContinue

				if (!$_.BastionHostSubnet) {
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - AzureBastionSubnet not found!"
					if (!$_.BastionHostSubnetPrefix) {
						Write-Error "Subnet prefix for AzureBastionSubnet subnet not found. Please provide cidr"  -targetobject $_.BastionHostSubnetPrefix
					}
				}
				else {
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - 'AzureBastionSubnet' subnet Found!"
					$_.BastionHostSubnetPrefix = ""
				}
			}
			New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
				-TemplateFile "$env:PermanentPSScriptRoot\New-CmAzIaasBastionHost.json" `
				-BastionHostObject $SettingsObject `
				-Location $env:Location `
				-workspace $workspace.CustomerId `
				-Verbose
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}