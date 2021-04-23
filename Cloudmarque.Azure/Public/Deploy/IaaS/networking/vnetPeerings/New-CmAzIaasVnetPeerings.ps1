function New-CmAzIaasVnetPeerings {

	<#
		.Synopsis
		 Creates vnet peerings.

		.Description
		 Completes following:
			* Creates vnet peerings on source vnet for target vnet.
			* Supports cross-subscription vnet peering.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 IaaS

		.Example
		 New-CmAzIaasVnetPeerings -settingsFile "vnetPeerings.yml"

        .Example
		 New-CmAzIaasVnetPeerings -settingsObject $vnetPeerings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings Yml File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

        $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create vnet peerings")) {

            $vnetPeerings = @()

			$azContext = Get-AzContext

            foreach ($peerConfig in $SettingsObject.peerings) {

                foreach ($target in $peerConfig.targets) {

                    $target.source = $peerConfig.source
                    $target.subscriptionId ??= $azContext.Subscription.id
                    $target.resourceGroup ??= $peerConfig.source.resourceGroup
                    $target.allowVirtualNetworkAccess ??= $false
                    $target.allowForwardedTraffic ??= $false
                    $target.allowGatewayTransit ??= $false
                    $target.useRemoteGateways ??= $false

                    $vnetPeerings += $target
                }
            }

            Write-Verbose "Configuring vnet peerings..."

            $location = (Get-AzResourceGroup -Name $vnetPeerings[0].source.resourceGroup).location
            $deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $location -Name "New-CmAzIaasVnetPeerings"

            New-AzDeployment `
                -Name $deploymentName `
                -TemplateFile $PSScriptRoot\New-CmAzIaasVnetPeerings.json `
                -Location $location `
                -VnetPeerings $vnetPeerings

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}
