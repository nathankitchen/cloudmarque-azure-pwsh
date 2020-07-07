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

		.Component
		IaaS

		.Example
		New-CmAzIaasVpnGw -SettingsFile "VpnGw.yml"

		.Example
		New-CmAzIaasVpnGw -SettingsObject $settings
	#>

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

				$_.VirtualNetworkName = (Get-CmAzService -Service $_.VnetTag -ThrowIfUnavailable).name
				$vnetObject = Get-AzVirtualNetwork -Name $_.VirtualNetworkName

				# Check if "GatewaySubnet Exists"

				Write-Verbose "Checking if 'GatewaySubnet' exists in Vnet."
				$gatewaySubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnetObject -ErrorAction SilentlyContinue

				if (!$gatewaySubnet) {

					Write-Verbose "GatewaySubnet not found."
					if (!$_.GatewaySubnetPrefix) {
						Write-Error "GatewaySubnet doesnt exist, please provide GatewaySubnetPrefix to create one." -TargetObject $_.GatewaySubnetPrefix
					}

					Write-Verbose "$($_.GatewaySubnetPrefix) will be used to create GatewaySubnet in Vnet"
				}
				else {

					Write-Verbose "GatewaySubnet Found!"
					$_.GatewaySubnetPrefix = ""
				}

				$_.GatewayPublicIpName = Get-CmAzResourceName `
					-Resource "PublicIPAddress" `
					-Architecture "IaaS" `
					-Region $env:location `
					-Name $_.GatewayName

				$_.GatewayName = Get-CmAzResourceName `
					-Resource "VirtualNetworkGateway" `
					-Architecture "IaaS" `
					-Region $env:location `
					-Name $_.GatewayName

				if (!$_.P2s.VpnAddressPool -or !$_.P2s.KeyVaultTag -or !$_.P2s.RootCertificateName) {

					Write-Verbose "P2s configuration not found."
					$_.P2s.VpnAddressPool = ""
					$_.P2s.ClientRootCertData = ""
					$_.P2s.RootCertificateName = ""
				}
				else {

					$keyVaultService = Get-CmAzService -Service $_.P2s.KeyVaultTag -ThrowIfUnavailable

					# This approach is because Vpn Gw expects Raw certificate data
					$keyVaultCertificateObject = Get-AzKeyVaultCertificate -VaultName $keyVaultService.name -Name $_.P2s.RootCertificateName
					$_.P2s.ClientRootCertData = [Convert]::ToBase64String($keyVaultCertificateObject.Certificate.GetRawCertData())

					if (!$_.P2s.ClientRootCertData) {

						Write-Verbose "Certificate Not Found! P2s will not be configured."
						$_.P2s.VpnAddressPool = ""
						$_.P2s.RootCertificateName = ""
						$_.P2s.ClientRootCertData = ""
					}
					else {
						Write-Verbose "Certificate $($_.P2s.RootCertificateName) found, p2s will be configured."
					}
				}
				if (!$_.S2s.ClientSitePublicIP -or !$_.S2s.CidrBlocks -or !$_.S2s.KeyVaultTag ) {

					Write-Verbose "S2s configuration not found."
					$_.S2s.CidrBlocks = @()
					$_.S2s.ClientSitePublicIP = ""
					$_.S2s.SharedKey = ""
				}
				else {
					# This apporach is because Key vault reference cannot be used directly in Arm template because of conflict with copy
					# SharedKeyObject is created to resolve with CLIXML type of object created when you run Az commands.
					$_.S2s.SharedKey = [System.Collections.ArrayList]@()
					$_.S2s.SharedKeyObject = (Get-AzKeyVaultSecret -Name $_.S2s.KeyVaultSecret -VaultName (Get-CmAzService -Service $_.S2s.KeyVaultTag -ThrowIfUnavailable).name).SecretValueText
					$_.S2s.SharedKey.add($_.S2s.SharedKeyObject.ToString()) > $null

					if (!$_.S2s.SharedKey) {

						Write-Verbose "Secret could not be retrieved! S2s configuration will be skipped."
						$_.S2s.CidrBlocks = @()
						$_.S2s.ClientSitePublicIP = ""
						$_.S2s.SharedKey = ""
					}
					else {
						Write-Verbose "Secret '$($_.S2s.KeyVaultSecret)' was found, s2s will be configured."
						$_.S2s.localGatewayName = Get-CmAzResourceName `
							-Resource "LocalNetworkGateway" `
							-Architecture "IaaS" `
							-Region $env:location `
							-Name $_.GatewayName
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