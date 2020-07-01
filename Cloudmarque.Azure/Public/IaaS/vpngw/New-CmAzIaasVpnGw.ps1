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

	.Component
	 IaaS

	.Example
	 New-CmAzIaasVpnGw -SettingsFile "VpnGw.yml"

	.Example
	 New-CmAzIaasVpnGw -SettingsObject $settings
#>
function New-CmAzIaasVpnGw {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File Path")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Set Virtual private network Gateway in Azure Vnet")) {

			if ($SettingsFile -and !$SettingsObject) {
                $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
            }
            elseif (!$SettingsFile -and !$SettingsObject) {
                Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
            }

			$env:location = $SettingsObject.Location
			$SettingsObject.ResourceGroupName = (Get-CmAzService -Service $SettingsObject.ResourceGroupTag -isResourceGroup -ThrowIfUnavailable).ResourceGroupName
			$SettingsObject.SubscriptionID = (Get-AzSubscription).id

			$SettingsObject.VpnGw | ForEach-Object -Parallel {

				$_.virtualNetworkName = (Get-CmAzService -Service $_.vnetTag -ThrowIfUnavailable).name
				$vnetObject = Get-AzVirtualNetwork -Name $_.virtualNetworkName

				# Check if "GatewaySubnet Exists"

				Write-Verbose "Checking if 'GatewaySubnet' exists in Vnet."
				$gatewaySubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnetObject -ErrorAction SilentlyContinue

				if (!$gatewaySubnet) {

					Write-Verbose "GatewaySubnet not found."
					if (!$_.gatewaySubnetPrefix) {
						Write-Error "GatewaySubnet doesnt exist, please provide GatewaySubnetPrefix to create one." -TargetObject $_.gatewaySubnetPrefix
					}

					Write-Verbose "$($_.gatewaySubnetPrefix) will be used to create GatewaySubnet in Vnet"
				}
				else {

					Write-Verbose "GatewaySubnet Found!"
					$_.gatewaySubnetPrefix = ""
				}

				$_.gatewayPublicIpName = Get-CmAzResourceName `
					-Resource "PublicIPAddress" `
					-Architecture "IaaS" `
					-Region $env:location `
					-Name $_.gatewayName

				$_.gatewayName = Get-CmAzResourceName `
					-Resource "VirtualNetworkGateway" `
					-Architecture "IaaS" `
					-Region $env:location `
					-Name $_.gatewayName

				if (!$_.p2s.vpnAddressPool -or !$_.p2s.KeyVaultTag -or !$_.p2s.rootCertificateName) {

					Write-Verbose "P2s configuration not found."
					$_.p2s.vpnAddressPool = ""
					$_.p2s.clientRootCertData = ""
					$_.p2s.rootCertificateName = ""
				}
				else {

					$keyVaultService = Get-CmAzService -Service $_.p2s.KeyVaultTag -ThrowIfUnavailable

					# This approach is because Vpn Gw expects Raw certificate data
					$keyVaultCertificateObject = Get-AzKeyVaultCertificate -VaultName $keyVaultService.name -Name $_.p2s.rootCertificateName
					$_.p2s.clientRootCertData = [Convert]::ToBase64String($keyVaultCertificateObject.Certificate.GetRawCertData())

					if (!$_.p2s.clientRootCertData) {

						Write-Verbose "Certificate Not Found! P2s will not be configured."
						$_.p2s.vpnAddressPool = ""
						$_.p2s.rootCertificateName = ""
						$_.p2s.clientRootCertData = ""
					}
					else {
						Write-Verbose "Certificate $($_.p2s.rootCertificateName) found, p2s will be configured."
					}
				}
				if (!$_.s2s.clientSitePublicIP -or !$_.s2s.cidrBlocks -or !$_.s2s.KeyVaultTag ) {

					Write-Verbose "S2s configuration not found."
					$_.s2s.cidrBlocks = @()
					$_.s2s.clientSitePublicIP = ""
					$_.s2s.sharedKey = ""
				}
				else {
					# This apporach is because Key vault reference cannot be used directly in Arm template because of conflict with copy
					# SharedKeyObject is created to resolve with CLIXML type of object created when you run Az commands.
					$_.s2s.sharedKey = [System.Collections.ArrayList]@()
					$_.s2s.sharedKeyObject = (Get-AzKeyVaultSecret -Name $_.s2s.KeyVaultSecret -VaultName (Get-CmAzService -Service $_.s2s.KeyVaultTag -ThrowIfUnavailable).name).SecretValueText
					$_.s2s.sharedKey.add($_.s2s.sharedKeyObject.ToString()) > $null

					if (!$_.s2s.sharedKey) {

						Write-Verbose "Secret could not be retrieved! S2s configuration will be skipped."
						$_.s2s.cidrBlocks = @()
						$_.s2s.clientSitePublicIP = ""
						$_.s2s.sharedKey = ""
					}
					else {
						Write-Verbose "Secret '$($_.s2s.KeyVaultSecret)' was found, s2s will be configured."
					}
				}
			}

			New-AzResourceGroupDeployment `
				-ResourceGroupName $SettingsObject.ResourceGroupName `
				-TemplateFile "$PSScriptRoot\New-CmAzIaasVpnGw.json" `
				-VpnGwObject $SettingsObject `
				-Location $env:location `
				-Verbose

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}