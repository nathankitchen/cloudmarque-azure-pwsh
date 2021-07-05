function New-CmAzIaasPrivateEndpoints {

	<#
		.Synopsis
		 Creates Private Networking components.

		.Description
		 Completes following:
			* Creates private DNS zone.
			* Creates private endpoints.
			* Supports integration of DNS Zones with virtual private network.
			* Supports integration of private DNS zone with private endpoint.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Parameter OmitTags
		 Parameter to specify if the cmdlet should handle its own tagging.

		.Component
		 IaaS

		.Example
		 New-CmAzIaasPrivateEndpoints -settingsFile "privateEndpoints.yml"

        .Example
		 New-CmAzIaasPrivateEndpoints -settingsObject $privateEndpoints
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings Yml File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[String]$TagSettingsFile,
		[bool]$OmitTags = $false
	)

	$ErrorActionPreference = "Stop"

	try {

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create Private Endpoints")) {

			foreach ($endpoint in $SettingsObject.privateEndpoints) {

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "resourceGroup" -ResourceServiceContainer $endpoint -IsDependency
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "vnet" -ResourceServiceContainer $endpoint -IsDependency
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "privateZones" -ResourceServiceContainer $endpoint -IsDependency -AllowMissing

				$endpoint.privateDnsZoneConfigs = @()

				$resourceGroup = Get-CmAzService -Service $endpoint.service.dependencies.resourceGroup -ThrowIfUnavailable -ThrowIfMultiple -IsResourceGroup
				$resource = Get-CmAzService -Service $endpoint.service.dependencies.resource -ThrowIfUnavailable -ThrowIfMultiple
				$vnet = Get-CmAzService -Service $endpoint.service.dependencies.vnet -ThrowIfUnavailable -ThrowIfMultiple

				if ($endpoint.resourceNameSpace) {

					$resource = (Get-CmAzService -Service $endpoint.service.dependencies.resource -ThrowIfUnavailable) | Where-Object { $_.resourceType -eq $endpoint.resourceNameSpace }

					if ($resource -is [array]) {

						Write-Error "Namespace has muliple resources with same service tag. Please correct your tagging scheme" -Category InvalidData
					}
				}
				else {
					$resource = Get-CmAzService -Service $endpoint.service.dependencies.resource -ThrowIfUnavailable -ThrowIfMultiple
				}

				foreach ($dnsZone in $endpoint.service.dependencies.privateZones) {

					$zone = Get-CmAzService -Service $dnsZone -ThrowIfUnavailable

					$zone | ForEach-Object {
						$endpoint.privateDnsZoneConfigs += @{
							name             = $_.resourceName.replace('.', '_')
							privateDnsZoneId = $_.resourceId
						}
					}
				}

				$endpoint.resourceGroupName = $resourceGroup.ResourceGroupName
				$endpoint.resourceId = $resource.resourceId
				$endpoint.vnetName = $vnet.ResourceName
				$endpoint.vnetResourceGroupName = $vnet.ResourceGroupName
				$endpoint.location ??= $resource.location

				if (!$endpoint.subResourceName -and !$SettingsObject.globalSubResourceName) {
					Write-Error "Provide Sub resource" -Category InvalidData
				}
				else {
					$endpoint.subResourceName ??= $SettingsObject.globalSubResourceName
				}

				$endpoint.name = Get-CmAzResourceName -Resource "PrivateEndpoint" `
					-Architecture "IaaS" `
					-Location $endpoint.location `
					-Name $endpoint.name

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "privateEndpoint" -ResourceServiceContainer $endpoint
			}

			Write-Verbose "Configuring Private endpoints..."

			$location = $SettingsObject.privateEndpoints[0].location
			$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $location -Name "New-CmAzIaasPrivateEndpoints"

			New-AzDeployment `
				-Name $deploymentName `
				-TemplateFile $PSScriptRoot\New-CmAzIaasPrivateEndpoints.json `
				-Location $location `
				-privateEndpoints $SettingsObject.privateEndpoints

			if (!$OmitTags) {
				$resourcesToSet = @()

				$resourcesToSet += $SettingsObject.privateEndpoints.name

				Write-Verbose "Started tagging for resources..."
				
				Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $resourcesToSet
			
				Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
			}
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}
