function New-CmAzPaasWeb {
	<#
		.Synopsis Create an Frontdoor with backing webapps

		.Description Completes following:
			* Creates Frontdoor
			* Creates Webapp and attaches to frontdoor
			* Optional API routing available

		.Parameter SettingsFile
		Path to configuration settings

		.Parameter SettingsObject
		Provide Azure Object

		.Component PaaS

		.Example
		New-CmAzPaasWeb -SettingsFile ./web.yml

		.Example
		New-CmAzPaasWeb -SettingsObject $settings
	#>

	[OutputType([System.Collections.ArrayList])]
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {
		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Azure - Frontdoor | Backendpool | Webapps along with routing rules")) {

			if ($SettingsFile -and -not $SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (-not $SettingsFile -and -not $SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			$resourceGroup = Get-CmAzService -Service $SettingsObject.ResourceGroupTag -Region $SettingsObject.Location -IsResourceGroup -ErrorAction SilentlyContinue
			if (!$resourceGroup) {
				$env:nameResourceGroup = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Region $SettingsObject.location -Name $SettingsObject.resourceGroupName
				Write-Verbose "Resourcegroup with tag $($SettingsObject.ResourceGroupTag) not found. New Resource Group '$($env:nameResourceGroup)' will be created."
				New-AzResourceGroup -ResourceGroupName $env:nameResourceGroup -Location $SettingsObject.location -Force
			}
			else {
				$env:nameResourceGroup = $resourceGroup.ResourceGroupName
			}
			$env:permanentPSScriptRoot = $PSScriptRoot

			if ($SettingsObject.monitoring.applicationInstrumentationKey) {
				$env:applicationInstrumentationKey = $SettingsObject.monitoring.applicationInstrumentationKey
			}
			else {
				$env:applicationInstrumentationKey = "none"
			}

			# Crawl across SettingsObject and create defined webapps
			$SettingsObject.AppServicePlans | ForEach-Object -Parallel {
				foreach ($app in $_.Webapps) {
					Write-Verbose "Initiating deployment of webapp : $($app.Name)"
					$kind = "linux"
					$linuxFxVersion = $app.Runtime
					$apptag = $app.Name
					$_.Name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture "PaaS" -Region $_.Region -Name $_.Name
					$app.Name = Get-CmAzResourceName -Resource "WebApp" -Architecture "PaaS" -Region $_.Region -Name $app.Name

					New-AzResourceGroupDeployment  `
						-Name $app.Name `
						-ResourceGroupName $env:nameResourceGroup `
						-TemplateFile "$env:permanentPSScriptRoot\New-CmAzPaasWeb.json" `
						-WhatIf:$WhatIfPreference `
						-WebAppName $app.Name `
						-Kind $kind `
						-LinuxFxVersion $linuxFxVersion  `
						-AppServicePlanName $_.Name `
						-Sku $_.Sku `
						-Location $_.Region `
						-Apptag $apptag `
						-StagingSlotName ($app.Slots).ToArray() `
						-AppInstrumatationKey $env:applicationInstrumentationKey `
						-Force `
						-Verbose

					Write-Verbose "$($app.Name) is created"
				}
			}

			#  Create FrontendEndpoint Object
			$SettingsObject.ApiManagementServices | foreach-object -parallel {
				if ($_.Name -and $_.Region -and $_.Organization -and $_.AdminEmail -and $_.Sku ) {
					try {
						$tag = @{"cm-paas-web" = $_.Name }
						$_.Name = Get-CmAzResourceName -Resource "APImanagementServiceInstance" -Architecture "PaaS" -Region $_.Region -Name $_.Name
						Write-Verbose "Creating ApiManagementService $($_.Name)"
						New-AzApiManagement `
							-ResourceGroupName $env:nameResourceGroup `
							-Location $_.Region `
							-Name $_.Name `
							-Organization $_.Organization `
							-AdminEmail $_.AdminEmail `
							-Sku $_.Sku `
							-Tag $tag

						while (!(([system.uri](Get-AzApiManagement -Name $_.Name -ResourceGroupName $env:nameResourceGroup).RuntimeUrl).Host)) {
							Start-Sleep -minutes 5
							Write-Verbose "Waiting for API To generate URL....."
						}
					}
					catch {
						Write-Verbose "There was some error or the API service is already present"
					}

					$url = ([system.uri](Get-AzApiManagement -Name $_.Name -ResourceGroupName $env:nameResourceGroup).RuntimeUrl).Host
					Write-Verbose "Api url: $($url)"

				}
			}
			function customDomainOnFrontDoorEnableHttps {
				param(
					$vaultName,
					$domainName,
					$secretName
				)
				if (!$vaultName) {
					Enable-AzFrontDoorCustomDomainHttps -ResourceGroupName $env:nameResourceGroup `
						-FrontDoorName $SettingsObject.frontDoor.hostName `
						-FrontendEndpointName ($frontendEndpointObjectArray | Where-Object Hostname -eq $domainName).Name `
						-MinimumTlsVersion "1.2"
				}
				else {
					Enable-AzFrontDoorCustomDomainHttps -ResourceGroupName $env:nameResourceGroup `
						-FrontDoorName $SettingsObject.frontDoor.hostName `
						-FrontendEndpointName ($frontendEndpointObjectArray | Where-Object Hostname -eq $domainName).Name `
						-Vault (Get-AzKeyVault -VaultName $vaultName).ResourceId `
						-secretName $secretName `
						-SecretVersion (Get-AzKeyVaultSecret -VaultName kvaultcorerg -Name $secretName).Version `
						-MinimumTlsVersion "1.0"
				}
			}

			$frontendEndpointObjectArray = [System.Collections.ArrayList]@()

			function setFrontendEndpointObject {
				param (
					$domainName,
					$sessionAffinity,
					$webApplicationFirewallPolicy,
					$name
				)
				if ($sessionAffinity) {
					$sessionAffinity = "Enabled"
				}
				else {
					$sessionAffinity = "Disabled"
				}

				Write-Verbose "Initiating creation of Frontend Endpoint Object"
				if ($SettingsObject.frontDoor.webApplicationFirewallPolicy) {
					$frontendEndpointObject = New-AzFrontDoorFrontendEndpointObject `
						-Name $name `
						-HostName $domainName `
						-SessionAffinityEnabledState $sessionAffinity `
						-WebApplicationFirewallPolicyLink $webApplicationFirewallPolicy
				}
				else {
					$frontendEndpointObject = New-AzFrontDoorFrontendEndpointObject `
						-Name $name `
						-HostName $domainName `
						-SessionAffinityEnabledState $sessionAffinity
				}
				$frontendEndpointObject
			}

			$frontendEndpointObjectMain = setFrontendEndpointObject -name $SettingsObject.frontDoor.hostName `
				-domainName "$($SettingsObject.frontDoor.hostName).azurefd.net" `
				-SessionAffinity $SettingsObject.frontDoor.sessionAffinity `
				-webApplicationFirewallPolicy $SettingsObject.frontDoor.webApplicationFirewallPolicy

			$frontendEndpointObjectArray.add($frontendEndpointObjectMain) > $null

			Write-Verbose "FrontEnd Local Hostname:"
			$frontendEndpointObjectMain

			if ($SettingsObject.frontDoor.customDomains.domainName) {
				foreach ($domain in $SettingsObject.frontDoor.customDomains) {
					Write-Verbose "Adding $($domain.domainName) Object"
					$frontendEndpointObjectCustom = setFrontendEndpointObject -name (Get-CmAzResourceName -Resource "frontDoor" -Architecture "Core" -Region $SettingsObject.location -Name "frontendCustomObject")`
						-domain $domain.domainName `
						-SessionAffinity $domain.sessionAffinity `
						-webApplicationFirewallPolicy $domain.webApplicationFirewallPolicy

					$frontendEndpointObjectArray.add($frontendEndpointObjectCustom) > $null
				}
				$frontendEndpointObjectArray
			}

			# Create Back end pool Object
			Write-Verbose "Initiating creation of Backend Endpoint Array of Backend Objects"
			$backEndPoolObjectArray = [System.Collections.ArrayList]@()
			$healthProbeSettingObjectArray = [System.Collections.ArrayList]@()
			$loadBalancingSettingObjectArray = [System.Collections.ArrayList]@()
			$routingRuleObjectArray = [System.Collections.ArrayList]@()

			foreach ($backEndPool in $SettingsObject.frontDoor.backEndPools) {
				$backendObjectArray = [System.Collections.ArrayList]@()
				foreach ($appname in $backEndPool.apps) {
					Write-Verbose "Checking $($appname) type"
					$appname = (Get-CmAzService -ServiceKey "cm-paas-web" -Service $appname).name
					$resourceType = (Get-AzResource -ResourceGroupName $env:nameResourceGroup -Name $appname).ResourceType
					Write-Verbose "Resource type identified to be : $($resourceType)"

					if ($resourceType -eq "Microsoft.ApiManagement/service") {
						$backEndDomainName = ([system.uri](Get-AzApiManagement -ResourceGroupName $env:nameResourceGroup -Name $appname).RuntimeUrl).Host
					}
					elseif ($resourceType -eq "Microsoft.Web/sites") {
						$backEndDomainName = (Get-AzWebApp -ResourceGroupName $env:nameResourceGroup -Name  $appname).DefaultHostName
					}
					else {
						Write-Verbose "Webapp $($appname) not found "
						break
					}
					if (!$backEndPool.backendHostHeader) {
						$backendHostHeader = ""
					}
					else {
						$backendHostHeader = $backEndDomainName
					}
					$backEndObject = New-AzFrontDoorBackendObject -Address $backEndDomainName -BackendHostHeader $backendHostHeader
					$backendObjectArray.Add($backEndObject) > $null
				}
				if (!$backEndPool.HealthCheckPath) {
					$backEndPool.HealthCheckPath = "/index.html"
				}
				if (!$backEndPool.protocol) {
					$backEndPool.protocol = "Https"
				}
				elseif ($backEndPool.protocol -eq "HTTP" -or $backEndPool.protocol -eq "http" -or $backEndPool.protocol -eq "Http") {
					$backEndPool.protocol = "Http"
				}
				elseif ($backEndPool.protocol -eq "HTTPS" -or $backEndPool.protocol -eq "https" -or $backEndPool.protocol -eq "Https") {
					$backEndPool.protocol = "Https"
				}
				$healthProbeSettingObject = New-AzFrontDoorHealthProbeSettingObject -Name "HealthProbeSetting-$($backEndPool.Name)" -Path  $backEndPool.HealthCheckPath -Protocol $backEndPool.protocol
				$loadBalancingSettingObject = New-AzFrontDoorLoadBalancingSettingObject -Name "Loadbalancingsetting-$($backEndPool.Name)"

				$backEndPoolObject = New-AzFrontDoorBackendPoolObject -Name $backEndPool.Name `
					-FrontDoorName $SettingsObject.frontDoor.hostName `
					-ResourceGroupName $env:nameResourceGroup `
					-Backend $backendObjectArray `
					-HealthProbeSettingsName "HealthProbeSetting-$($backEndPool.Name)" `
					-LoadBalancingSettingsName "Loadbalancingsetting-$($backEndPool.Name)"

				Write-Verbose "Backend Pool Object Created for $($backEndPool.Name)"

				$backEndPoolObjectArray.Add($backEndPoolObject) > $null
				$healthProbeSettingObjectArray.Add($healthProbeSettingObject) > $null
				$loadBalancingSettingObjectArray.Add($loadBalancingSettingObject) > $null
			}

			foreach ($rule in $SettingsObject.frontDoor.rules) {
				foreach ($endpointObject in $frontendEndpointObjectArray) {
					$routingRuleObject = New-AzFrontDoorRoutingRuleObject -Name $rule.Name `
						-FrontDoorName $SettingsObject.frontDoor.hostName `
						-ResourceGroupName $env:nameResourceGroup `
						-FrontendEndpointName $endpointObject.Name `
						-BackendPoolName  $rule.backEndPoolName `
						-PatternToMatch  $rule.Pattern
				}
				$routingRuleObject
				$routingRuleObjectArray.Add($routingRuleObject) > $null
			}

			# Create Frontdoor
			Write-Verbose "Initiating creation of Azure frontdoor"

			New-AzFrontDoor -Name $SettingsObject.frontDoor.hostName `
				-ResourceGroupName $env:nameResourceGroup `
				-FrontendEndpoint $frontendEndpointObjectArray `
				-BackendPool $backEndPoolObjectArray `
				-HealthProbeSetting $healthProbeSettingObjectArray `
				-LoadBalancingSetting $loadBalancingSettingObjectArray `
				-RoutingRule $routingRuleObjectArray


			if ($SettingsObject.frontDoor.customDomains.domainName) {
				foreach ($domain in $SettingsObject.frontDoor.customDomains) {
					customDomainOnFrontDoorEnableHttps -domainName $domain.domainName -VaultName $domain.customCertificateVaultName -secretName $domain.customCertificateSecretName
				}
			}

			if ($SettingsObject.contentDeliveryNetwork.Name) {
				$resourceType = (Get-AzResource -ResourceGroupName $env:nameResourceGroup -Name $SettingsObject.contentDeliveryNetwork.attachObjectName -ErrorAction SilentlyContinue).ResourceType
				Write-Verbose "Resource type identified to be : $($resourceType)"

				if ($resourceType -eq "Microsoft.Storage/storageAccounts") {
					$domain = ([system.uri](New-AzStorageContext -StorageAccountName  $SettingsObject.contentDeliveryNetwork.attachObjectName).BlobEndPoint).Host
				}
				elseif ($resourceType -eq "Microsoft.Web/sites") {
					$domain = (Get-AzWebApp -ResourceGroupName $env:nameResourceGroup -Name  $SettingsObject.contentDeliveryNetwork.attachObjectName).DefaultHostName
				}
				else {
					Write-Verbose "$($SettingsObject.contentDeliveryNetwork.attachObjectName) not found "
					break
				}
				# Create a new profile and endpoint in one line
				$cdn = New-AzCdnProfile -ProfileName $SettingsObject.contentDeliveryNetwork.Name -ResourceGroupName $env:nameResourceGroup -Sku $SettingsObject.contentDeliveryNetwork.Sku -Location $SettingsObject.location | `
					New-AzCdnEndpoint -EndpointName $SettingsObject.contentDeliveryNetwork.Name -OriginName $SettingsObject.contentDeliveryNetwork.attachObjectName -OriginHostName $domain

				$cdn | Write-Verbose
			}

			# Clean up environment
			Remove-Item env:nameResourceGroup
			Write-Verbose "Clean up environment..Done"
			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}

}