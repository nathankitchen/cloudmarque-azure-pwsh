function New-CmAzIaasVpnGw {

	<#
		.Synopsis
		 Set Virtual private network Gateway in Azure Vnet

		.Description
		 Completes the following:
			* This script creates Vpn Gateways in provided Vnets.
			* Optionally configures P2s and S2s.
			* Secrets and certificates are securely retrieved from Keyvault

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Component
		 IaaS

		.Example
		 New-CmAzIaasVpnGw -SettingsFile "VpnGw.yml"

		.Example
		 New-CmAzIaasVpnGw -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Set Virtual private network Gateway in Azure Vnet")) {

			$SettingsObject.resourceGroupName = (Get-CmAzService -Service $SettingsObject.service.dependencies.resourcegroup -IsResourceGroup -ThrowIfUnavailable -ThrowIfMultiple).ResourceGroupName

			$resourcesToBeSet = @()

			foreach ($vpnGw in $SettingsObject.VpnGw) {

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "vnet" -ResourceServiceContainer $vpnGw -IsDependency
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "resourceGroup" -ResourceServiceContainer $vpnGw -IsDependency

				$vpnGw.VirtualNetworkName = (Get-CmAzService -Service $vpnGw.service.dependencies.vnet -ThrowIfUnavailable -ThrowIfMultiple).name

				$vnetObject = Get-AzVirtualNetwork -Name $vpnGw.VirtualNetworkName

				# Check if "GatewaySubnet Exists"

				Write-Verbose "Checking if 'GatewaySubnet' exists in Vnet."
				$gatewaySubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnetObject -ErrorAction SilentlyContinue

				if (!$gatewaySubnet) {

					Write-Verbose "GatewaySubnet not found."

					if (!$vpnGw.GatewaySubnetPrefix) {
						Write-Error "GatewaySubnet doesnt exist, please provide GatewaySubnetPrefix to create one." -TargetObject $vpnGw.GatewaySubnetPrefix
					}

					Write-Verbose "$($vpnGw.GatewaySubnetPrefix) will be used to create GatewaySubnet in Vnet"
				}
				else {
					Write-Verbose "GatewaySubnet Found!"
					$vpnGw.GatewaySubnetPrefix = ""
				}

				$vpnGw.GatewayPublicIpName = Get-CmAzResourceName `
					-Resource "PublicIPAddress" `
					-Architecture "IaaS" `
					-Location $SettingsObject.location `
					-Name $vpnGw.GatewayName

				$vpnGw.GatewayName = Get-CmAzResourceName `
					-Resource "VirtualNetworkGateway" `
					-Architecture "IaaS" `
					-Location $SettingsObject.location `
					-Name $vpnGw.GatewayName


				if ($vpnGw.P2s -or $vpnGw.S2s) {
					Write-Verbose "P2s or S2s configuration found. Checking dependencies.."
					Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "keyvault" -ResourceServiceContainer $vpnGw -IsDependency
				}

				if (!$vpnGw.P2s.VpnAddressPool -or !$vpnGw.service.dependencies.keyvault -or !$vpnGw.P2s.RootCertificateName) {

					Write-Verbose "P2s configuration not found."
					$vpnGw.P2s = @{}
					$vpnGw.P2s.VpnAddressPool = ""
					$vpnGw.P2s.ClientRootCertData = ""
					$vpnGw.P2s.RootCertificateName = ""
				}
				else {

					$keyVaultService = Get-CmAzService -Service $vpnGw.service.dependencies.keyvault -ThrowIfUnavailable -ThrowIfMultiple

					# This approach is because Vpn Gw expects Raw certificate data
					$keyVaultCertificateObject = Get-AzKeyVaultCertificate -VaultName $keyVaultService.name -Name $vpnGw.P2s.RootCertificateName

					if (!$keyVaultCertificateObject) {

						Write-Verbose "Certificate Not Found! P2s will not be configured."
						$vpnGw.P2s = @{}
						$vpnGw.P2s.VpnAddressPool = ""
						$vpnGw.P2s.RootCertificateName = ""
						$vpnGw.P2s.ClientRootCertData = ""
					}
					else {
						Write-Verbose "Certificate $($vpnGw.P2s.RootCertificateName) found, p2s will be configured."
						$clientRootCertData = $keyVaultCertificateObject.Certificate.GetRawCertData()
						$vpnGw.P2s.ClientRootCertData = [Convert]::ToBase64String($clientRootCertData)
					}
				}

				if (!$vpnGw.S2s.ClientSitePublicIP -or !$vpnGw.S2s.CidrBlocks -or !$vpnGw.service.dependencies.keyvault ) {

						Write-Verbose "S2s configuration not found."
						$vpnGw.S2s = @{}
						$vpnGw.S2s.CidrBlocks = @()
						$vpnGw.S2s.ClientSitePublicIP = ""
						$vpnGw.S2s.SharedKey = ""
						$vpnGw.S2s.localGatewayName = "none"
				}
				else {

					# This apporach is because Key vault reference cannot be used directly in Arm template because of conflict with copy
					# SharedKeyObject is created to resolve with CLIXML type of object created when you run Az commands.
					$keyVaultService = Get-CmAzService -Service $vpnGw.service.dependencies.keyvault -ThrowIfUnavailable -ThrowIfMultiple
					$vpnGw.S2s.SharedKey = @()
					$vpnGw.S2s.SharedKeyObject = (Get-AzKeyVaultSecret -Name $vpnGw.S2s.KeyVaultSecret -VaultName ($keyVaultService.name)).SecretValueText

					if (!$vpnGw.S2s.SharedKeyObject) {

						Write-Verbose "Secret could not be retrieved! S2s configuration will be skipped."
						$vpnGw.S2s = @{}
						$vpnGw.S2s.CidrBlocks = @()
						$vpnGw.S2s.ClientSitePublicIP = ""
						$vpnGw.S2s.SharedKey = ""
						$vpnGw.S2s.localGatewayName = "none"
					}
					else {

						Write-Verbose "Secret '$($vpnGw.S2s.KeyVaultSecret)' was found, s2s will be configured."
						$vpnGw.S2s.localGatewayName = Get-CmAzResourceName `
							-Resource "LocalNetworkGateway" `
							-Architecture "IaaS" `
							-Location $SettingsObject.location `
							-Name $vpnGw.GatewayName

						$resourcesToBeSet += $vpnGw.S2s.localGatewayName
						$vpnGw.S2s.SharedKey = $vpnGw.S2s.SharedKeyObject.ToString()
					}
				}

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "publicIp" -ResourceServiceContainer $vpnGw
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "virtualNetworkGateway" -ResourceServiceContainer $vpnGw
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "localNetworkGateway" -ResourceServiceContainer $vpnGw
			}
			Write-Verbose "Deploying Vpn Gateways..."

			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.location -Name "New-CmAzIaasVpnGw"

			New-AzResourceGroupDeployment `
				-Name $deploymentName `
				-ResourceGroupName $SettingsObject.ResourceGroupName `
				-TemplateFile "$PSScriptRoot\New-CmAzIaasVpnGw.json" `
				-VpnGwObject $SettingsObject `
				-Location $SettingsObject.location `
				-Force

			$resourcesToBeSet += $SettingsObject.vpnGw.gatewayPublicIpName
			$resourcesToBeSet += $SettingsObject.vpnGw.gatewayName

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $resourceIds

			Write-Verbose "Finished."
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}