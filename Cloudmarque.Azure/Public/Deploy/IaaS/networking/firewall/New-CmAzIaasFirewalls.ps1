function New-CmAzIaasFirewalls {

	<#
		.Synopsis
		 Creates multiple firewalls and policies

		.Description
		 Completes the following:
			* Creates firewall polices.
			* Creates firewalls.
			* Creates firewall subnet.

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
		 New-CmAzIaasFirewalls -settingsFile "firewalls.yml"

        .Example
		 New-CmAzIaasFirewalls -settingsObject $firewalls
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings Yml File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create firewalls")) {

			foreach ($firewallPolicy in $SettingsObject.firewallPolicies) {

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "resourceGroup" -ResourceServiceContainer $firewallPolicy -IsDependency
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "vnet" -ResourceServiceContainer $firewallPolicy -IsDependency

				$resourceGroup = Get-CmAzService -Service $firewallPolicy.service.dependencies.resourceGroup -ThrowIfMultiple -IsResourceGroup
				$vnet = Get-CmAzService -Service $firewallPolicy.service.dependencies.vnet -ThrowIfMultiple -ThrowIfUnavailable

				if ($firewallPolicy.service.dependencies.baseFirewallPolicy) {
					$basePolicy = Get-CmAzService -Service $firewallPolicy.service.dependencies.baseFirewallPolicy -ThrowIfUnavailable -ThrowIfMultiple
					$firewallPolicy.basePolicy = @{ id = $basePolicy.ResourceId }
				}
				else {
					$firewallPolicy.basePolicy = @{}
				}

				$firewallPolicy.resourceGroupName = $resourceGroup.resourceGroupName ? $resourceGroup.resourceGroupName : $vnet.resourceGroupName
				$firewallPolicy.location ??= $vnet.location ? $vnet.location : $resourceGroup.location
				$firewallPolicy.threatIntelMode ??= "Alert"
				$firewallPolicy.threatIntelWhitelist ??= @{ipAddresses = @(); fqdns = @() }
				$firewallPolicy.dnsSettings ??= @{}
				$firewallPolicy.ruleCollectionGroups ??= @()

				foreach ($ruleCollectionGroupsSettingFile in $firewallPolicy.ruleCollectionGroupsSettingFiles) {
					$firewallPolicy.ruleCollectionGroups += (Get-Settings -SettingsFile $ruleCollectionGroupsSettingFile `
																 -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath) `
																 -SubSchema 'New-CmAzIaasFirewalls.RuleCollectionGroups.SubSchema.json' ).ruleCollectionGroups
				}

				foreach ($ruleCollection in $firewallPolicy.ruleCollectionGroups.ruleCollections) {

					switch ($ruleCollection.type) {

						dnat {
							$ruleCollection.ruleCollectionType = "FirewallPolicyNatRuleCollection"
							$ruleType = "NatRule"
							$ruleCollection.actionType ??= "Dnat"
						}

						network {
							$ruleCollection.ruleCollectionType = "FirewallPolicyFilterRuleCollection"
							$ruleType = "NetworkRule"
							$ruleCollection.actionType ??= "allow"
						}

						application {
							$ruleCollection.ruleCollectionType = "FirewallPolicyFilterRuleCollection"
							$ruleType = "ApplicationRule"
							$ruleCollection.actionType ??= "allow"
						}
					}

					foreach ($rule in $ruleCollection.rules ) {
						$rule.ruleType = $ruleType
					}
				}

				if (!($firewallPolicy.ruleCollectionGroups -is [array])) {
					$firewallPolicy.ruleCollectionGroups = @($firewallPolicy.ruleCollectionGroups)
				}

				if (!$firewallPolicy.ruleCollectionGroups) {
					$firewallPolicy.ruleCollectionGroups = @(@{name = 'none'; ruleCollections = @() })

				}
				$firewallPolicy.name = Get-CmAzResourceName -Resource "firewallPolicy" `
					-Architecture "IaaS" `
					-Location $firewallPolicy.location `
					-Name $firewallPolicy.name

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "firewallPolicy" -ResourceServiceContainer $firewallPolicy
			}

			if ($SettingsObject.firewallPolicies) {

				Write-Verbose "Configuring firewall policies..."

				$location = $SettingsObject.firewallPolicies[0].location
				$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $location -Name "New-CmAzIaasFirewalls-Policies"

				New-AzDeployment `
					-Name $deploymentName `
					-TemplateFile $PSScriptRoot\New-CmAzIaasFirewallPolicies.json `
					-Location $location `
					-firewallPolicies $SettingsObject.firewallPolicies
			}


			foreach ($firewall in $SettingsObject.firewalls) {

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "vnet" -ResourceServiceContainer $firewall -IsDependency
				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "firewallPolicy" -ResourceServiceContainer $firewall -IsDependency

				$vnet = Get-CmAzService -Service $firewall.service.dependencies.vnet -ThrowIfUnavailable -ThrowIfMultiple

				$firewallPolicyService = $SettingsObject.firewallPolicies | Where-Object { $_.service.publish.firewallPolicy -eq $firewall.service.dependencies.firewallPolicy }

				if ($firewallPolicyService -is [array]) {
					Write-Error "Multiple firewall policies have same tags. Please provide unique service tag." -Category InvalidData -TargetObject $firewallPolicyService
				}

				$firewallPolicyService ??= Get-CmAzService -Service $firewall.service.dependencies.firewallPolicy -ThrowIfUnavailable -ThrowIfMultiple

				$firewall.firewallPolicy = @{
					resourceGroupName = $firewallPolicyService.resourceGroupName
					name              = $firewallPolicyService.name ?  $firewallPolicyService.name  : $firewallPolicyService.resourceName
				}

				$firewall.location = $vnet.location
				$firewall.resourceGroupName = $vnet.resourceGroupName
				$firewall.vnetName = $vnet.resourceName

				$firewall.name = Get-CmAzResourceName -Resource "firewall" `
					-Architecture "IaaS" `
					-Location $firewall.location `
					-Name $firewall.name

				$firewall.publicIpAddressName = Get-CmAzResourceName -Resource "PublicIPAddress" `
					-Architecture "IaaS" `
					-Location $firewall.location `
					-Name $firewall.name

				Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "firewall" -ResourceServiceContainer $firewall
			}

			if ($SettingsObject.firewalls) {

				Write-Verbose "Configuring firewalls..."

				$location = $SettingsObject.firewalls[0].location
				$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $location -Name "New-CmAzIaasFirewalls"

				New-AzDeployment `
					-Name $deploymentName `
					-TemplateFile $PSScriptRoot\New-CmAzIaasFirewalls.json `
					-Location $location `
					-firewalls $SettingsObject.firewalls
			}
		}

		Write-Verbose "Started tagging for firewall policies..."
		Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $SettingsObject.firewallPolicies.name

		Write-Verbose "Started tagging for firewall..."
		Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $SettingsObject.firewalls.name

	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}
