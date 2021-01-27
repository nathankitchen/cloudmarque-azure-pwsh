function New-CmAzPaasWeb {

	<#
		.Synopsis
		 Create an Frontdoor with backing webapps

		.Description
		 Completes following:
			* Creates Frontdoor
			* Creates Webapp and attaches to frontdoor
			* Optional API routing available

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
     	 File path for the tag settings file to be converted into a tag settings object.

		.Component
		 PaaS

		.Example
		 New-CmAzPaasWeb -SettingsFile ./web.yml

		.Example
		 New-CmAzPaasWeb -SettingsObject $settings

		.Example
		 New-CmAzPaasWeb -SettingsObject $settings -TagSettingFile ./tag.yml
	#>

	[OutputType([System.Collections.ArrayList])]
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

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Azure - Frontdoor | Backendpool | Webapps along with routing rules")) {

			if ($SettingsFile -and -not $SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (-not $SettingsFile -and -not $SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			$azContext = Get-AzContext

			$applicationInstrumentationKey = ""

			if ($SettingsObject.service.dependencies.appInsights) {

				Write-Verbose "Fetching appinsights instrumentation key..."
				$appInsightsService = Get-CmAzService -Service $SettingsObject.service.dependencies.appInsights -ThrowIfUnavailable -ThrowIfMultiple
				$appInsights = Get-AzApplicationInsights -ResourceGroupName $appInsightsService.resourceGroupName -Name $appInsightsService.name

				$applicationInstrumentationKey = $appInsights.InstrumentationKey
			}

			[System.Collections.ArrayList]$resourceGroupsToSet = @()

			function New-ResourceGroup() {

				param(
					$resourceGroupName,
					$ResourceServiceContainer,
					$GlobalServiceContainer,
					$Region,
					$ServiceKey
				)

				$generatedResourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Region $Region -Name $resourceGroupName

				Set-GlobalServiceValues -GlobalServiceContainer $GlobalServiceContainer -ServiceKey $serviceKey -ResourceServiceContainer $ResourceServiceContainer > $null
				New-AzResourceGroup -ResourceGroupName $generatedResourceGroupName -Location $Region -Tag @{ "cm-service" = $ResourceServiceContainer.service.publish.resourceGroup } -Force > $null

				$resourceGroupsToSet.Add($generatedResourceGroupName) > $Null

				return $generatedResourceGroupName
			}

			# Crawl across SettingsObject and create defined webapps

			foreach ($webSolution in $SettingsObject.WebSolutions) {

				if ($webSolution.AppServicePlans.Region.count -gt 1) {
					$region = $webSolution.AppServicePlans[0].Region
				}
				else {
					$region = $webSolution.AppServicePlans.Region
				}

				if (!$region) {
					if ($webSolution.apiManagementServices.Region.count -gt 1) {
						$region = $webSolution.apiManagementServices[0].Region
					}
					else {
						$region = $webSolution.apiManagementServices.Region
					}
				}

				$webSolution.generatedResourceGroupName = New-ResourceGroup `
					-ResourceGroupName $webSolution.Name `
					-GlobalServiceContainer $SettingsObject `
					-ResourceServiceContainer $webSolution `
					-Region $region `
					-ServiceKey "resourceGroup"

				if ($webSolution.AppServicePlans) {

					foreach ($appServicePlan in $webSolution.AppServicePlans) {

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "appServicePlan" -ResourceServiceContainer $appServicePlan
						$appServicePlan.name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture "PaaS" -Region $appServicePlan.region -Name $appServicePlan.name

						if (!$appServicePlan.kind) {
							$appServicePlan.kind = "linux"
						}

						if (!$appServicePlan.region) {
							Write-Error "Please provide region for service plan."
						}

						$appServicePlan.resourceGroupName = $webSolution.generatedResourceGroupName

						foreach ($webapp in $appServicePlan.webapps) {

							Write-Verbose "Generating Object for deployment of webapp : $($webapp.name)..."

							if (!$webapp.region) {
								$webapp.region = $appServicePlan.region
							}

							$webapp.webAppGeneratedName = Get-CmAzResourceName -Resource "WebApp" -Architecture "PaaS" -Region $webapp.region -Name $webapp.name

							Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "webapp" -ResourceServiceContainer $webapp

							if (!$webapp.Slots) {
								$webapp.slotsObject = @(@{ name = "none"; service = @{ publish = @{ slot = $null } } })
							}
							else {
								$webapp.slotsObject = [System.Collections.ArrayList]@()

								foreach ($slot in $webapp.Slots) {

									if ($slot -Is [System.String]) {
										$slotObject = @{ Name = $slot }
									}
									else {
										$slotObject = $slot
									}

									Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "slot" -ResourceServiceContainer $slotObject

									Write-Verbose "Adding slot: $($slotObject.name) to webapp : $($webapp.Name)..."
									$webapp.slotsObject.Add($slotObject) > $null
								}
							}

							if ($webapp.contentDeliveryNetwork.Name) {

								$webapp.contentDeliveryNetwork.Name = Get-CmAzResourceName -Resource "CdnProfile" -Architecture "PaaS" -Region $webapp.contentDeliveryNetwork.region -Name $webapp.contentDeliveryNetwork.Name

								Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "cdn" -ResourceServiceContainer $webapp.contentDeliveryNetwork
								Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "endpoint" -ResourceServiceContainer $webapp.contentDeliveryNetwork
							}
							else {
								$webapp.contentDeliveryNetwork = @{
									name    = "none";
									sku     = "standard_microsoft";
									region  = "global";
									service = @{
										publish = @{
											cdn      = $null;
											endpoint = $null
										}
									}
								}
							}

							if ($webapp.enableAppInsight) {
								$webapp.applicationInstrumentationKey = $applicationInstrumentationKey
							}
							else {
								$webapp.applicationInstrumentationKey = ""
							}
						}
					}
				}

				if ($webSolution.ApiManagementServices ) {

					$webSolution.ApiManagementServices | forEach-Object {

						if (!$_.Name -or !$_.publisherName -or !$_.publisherEmail -or !$_.Sku ) {
							Write-Error "Api gateway is missing mandatory parameters. Please provide name, region, organization, admin email and sku."
						}

						if (!$_.region) {
							Write-Error "Please provide region for api management service"
						}

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "apiManagement" -ResourceServiceContainer $_

						$_.resourceGroupName = $webSolution.generatedResourceGroupName

						if (!$_.skucount) {
							$_.skucount = 1
						}

						$_.generatedName = Get-CmAzResourceName -Resource "APImanagementServiceInstance" -Architecture "PaaS" -Region $_.Region -Name $_.Name
					}


				}
			}

			if ($SettingsObject.WebSolutions.appServicePlans) {

				if ($SettingsObject.WebSolutions.AppServicePlans.Region.count -gt 1) {
					$region = $SettingsObject.WebSolutions.AppServicePlans[0].Region
				}
				else {
					$region = $SettingsObject.WebSolutions.AppServicePlans.Region
				}

				[System.Collections.ArrayList]$AppServiceDetails = @()
				$AppServiceDetails += $SettingsObject.WebSolutions.AppServicePlans

				Write-Verbose "Initiating deployment of webapps..."

				New-AzDeployment  `
					-Name "CmAzWebStack_Parent" `
					-Location $region `
					-TemplateFile "$PSScriptRoot\New-CmAzPaasWeb-Webapp.json" `
					-AppServiceDetails $AppServiceDetails
			}

			if ($SettingsObject.WebSolutions.ApiManagementServices) {

				if ($SettingsObject.WebSolutions.ApiManagementServices.Region.count -gt 1) {
					$region = $SettingsObject.WebSolutions.ApiManagementServices[0].Region
				}
				else {
					$region = $SettingsObject.WebSolutions.ApiManagementServices.Region
				}

				[System.Collections.ArrayList]$ApiManagementServices = @()
				$ApiManagementServices += $SettingsObject.WebSolutions.ApiManagementServices

				Write-Verbose "Initiating deployment of api management services..."

				New-AzDeployment  `
					-Name "CmAzApiManagementServices_Parent" `
					-Location $region `
					-TemplateFile "$PSScriptRoot\New-CmAzPaasWeb-ApiManagementServices.json" `
					-ApiManagementServices $ApiManagementServices
			}


			if ($SettingsObject.frontdoor) {

				# Frontdoor configuration:
				$frontendEndpointObjectArray = [System.Collections.ArrayList]@()

				$frontdoorRG = New-ResourceGroup `
					-ResourceGroupName $SettingsObject.frontdoor.name `
					-GlobalServiceContainer $SettingsObject `
					-ResourceServiceContainer $SettingsObject.frontdoor `
					-Region $SettingsObject.frontdoor.region `
					-ServiceKey "frontDoorResourceGroup"

				Write-Verbose "Initiating compilation of Frontends..."

				$frontdoorSuppliedHostName = $SettingsObject.frontdoor.name
				$SettingsObject.frontdoor.name = Get-CmAzResourceName -Resource "FrontDoor" -Architecture "PaaS" -Region $SettingsObject.frontdoor.region -Name $SettingsObject.frontdoor.name

				# Frontdoor Front endpoints configuration

				if ($SettingsObject.frontdoor.service.dependencies.webApplicationFirewallPolicy) {

					$webApplicationFirewallPolicyService = @{
						id = (Get-CmAzService -Service $SettingsObject.frontdoor.service.dependencies.webApplicationFirewallPolicy -ThrowIfUnavailable -ThrowIfMultiple).ResourceId
					}
				}

				$frontendEndpointObjectMain = @{
					frontEndName                           = $SettingsObject.frontdoor.name;
					domainName                             = "$($SettingsObject.frontdoor.name).azurefd.net"
					sessionAffinity                        = $SettingsObject.frontdoor.sessionAffinity
					webApplicationFirewallPolicyResourceId = $webApplicationFirewallPolicyService
				}

				Write-Verbose "Frontdoor Azure FQDN: $($SettingsObject.frontdoor.name).azurefd.net..."

				$frontendEndpointObjectArray.Add($frontendEndpointObjectMain) > $Null

				if ($SettingsObject.frontDoor.customDomains.domainName) {

					$SettingsObject.frontDoor.customDomains | forEach-Object {

						Write-Verbose "Adding $($_.domainName) to FrontDoor endpoint configuration..."

						if ($_.service.dependencies.webApplicationFirewallPolicy) {
							$CustomWebApplicationFirewallPolicyService = @{
								id = (Get-CmAzService -Service $_.service.dependencies.webApplicationFirewallPolicy -ThrowIfUnavailable -ThrowIfMultiple).ResourceId
							}
						}

						$frontendEndpointObjectCustom = @{
							frontEndName                           = $_.domainName.replace('.', '-');
							domainName                             = $_.domainName
							sessionAffinity                        = $_.sessionAffinity
							webApplicationFirewallPolicyResourceId = $CustomWebApplicationFirewallPolicyService
						}

						$frontendEndpointObjectArray.add($frontendEndpointObjectCustom) > $null
					}
				}

				$SettingsObject.FrontDoor.frontendEndpoints = $frontendEndpointObjectArray

				# Frontdoor backendpools configuration

				Write-Verbose "Initiating compilation of Backend Pools..."

				foreach ($backEndPool in $SettingsObject.frontDoor.backEndPools) {

					if (($SettingsObject.Websolutions.appServicePlans.webapps.backendpool -contains $backEndPool.Name) -or ($SettingsObject.Websolutions.ApiManagementServices.backendPool -contains $backEndPool.Name)) {

						Write-Verbose "Adding backend pool: $($backEndPool.Name) to FrontDoor backend configuration..."

						$backEndPool.backends = [System.Collections.ArrayList]@()

						$SettingsObject.Websolutions.appServicePlans.webapps | Where-Object { $_.backendpool -match $backEndPool.Name } | forEach-Object {

							$address = "$($_.webAppGeneratedName).azurewebsites.net"
							$backendHostHeader = $address

							if ($_.backendHostHeader -eq $false) {
								$backendHostHeader = ""
							}

							if (!$_.weight) {
								$_.weight = 100
							}

							if (!$_.priority) {
								$_.priority = 1
							}

							$backEndObject = @{
								Address           = $address;
								httpPort          = 80;
								httpsPort         = 443;
								weight            = $_.weight ;
								priority          = $_.priority ;
								enabledState      = "Enabled";
								backendHostHeader = $backendHostHeader
							}

							$backEndPool.backends.Add($backEndObject) > $null
						}

						$SettingsObject.Websolutions.ApiManagementServices | Where-Object { $_.backendPool -eq $backEndPool.Name } | forEach-Object {

							$address = "$($_.generatedName).azure-api.net"
							$backendHostHeader = $address

							if ($_.backendHostHeader -eq $false) {
								$backendHostHeader = ""
							}

							if (!$_.weight) {
								$_.weight = 100
							}

							if (!$_.priority) {
								$_.priority = 1
							}

							$backEndObject = @{
								Address           = $address;
								httpPort          = 80;
								httpsPort         = 443;
								weight            = $_.weight ;
								priority          = $_.priority ;
								enabledState      = "Enabled";
								backendHostHeader = $backendHostHeader
							}

							$backEndPool.backends.Add($backEndObject) > $null
						}

						if (!$backEndPool.healthCheckPath) {
							$backEndPool.healthCheckPath = "/index.html"
						}

						if (!$backEndPool.protocol) {
							$backEndPool.protocol = "Https"
						}
						elseif ($backEndPool.protocol -ne "Https" -and $backEndPool.protocol -ne "Http") {
							Write-Error "Invalid backend pool protocol." -Category InvalidArgument -CategoryTargetName "SettingsObject.frontdoor.backendPools.protocol"
						}
					}
					else {
						Write-Error "Backend pool: $($backEndPool.Name) not found" -Category ObjectNotFound -TargetObject $backEndPool.Name
					}
				}

				# Frondoor routing rules configuration

				Write-Verbose "Initiating compilation of routing rules..."

				foreach ($routingRule in $SettingsObject.frontDoor.rules) {

					Write-Verbose "Adding backend pool: $($routingRule.Name) to FrontDoor routing rule configuration..."

					$routingRule.frontendEndpoints = [System.Collections.ArrayList]@()

					if (!$routingRule.endpoints){
						$routingRule.endpoints = @($frontdoorSuppliedHostName)
					}

					foreach ($endpoint in $routingRule.endpoints) {

						if ($endpoint -match $frontdoorSuppliedHostName) {
							$endpoint = $SettingsObject.frontdoor.name
						}
						else {
							$endpoint = $endpoint.replace('.', '-')
						}

						$frontEndPointObject = @{
							id = "/subscriptions/$($azContext.Subscription.Id)/resourcegroups/$frontdoorRG/providers/Microsoft.Network/Frontdoors/$($SettingsObject.frontdoor.name)/FrontendEndpoints/$endpoint"
						}

						$routingRule.frontendEndpoints.Add($frontEndPointObject) > $Null
					}

					if (!$routingRule.acceptedProtocols) {
						$routingRule.acceptedProtocols = @("Https", "Http")
					}

					if ($routingRule.enableCaching) {
						$routingRule.cacheConfiguration = @{
							queryParameterStripDirective = "StripNone";
							dynamicCompression           = "Enabled"
						}
					} else {
						$routingRule.cacheConfiguration = $null
					}
				}

				New-AzResourceGroupDeployment  `
					-Name "CmAz_Frontdoor" `
					-ResourceGroupName $frontdoorRG `
					-TemplateFile "$PSScriptRoot\New-CmAzPaasWeb-Frontdoor.json" `
					-Frontdoor $SettingsObject.frontdoor `
					-FrontdoorService $SettingsObject.service.publish.frontDoor `
					-Verbose

				if ($SettingsObject.frontDoor.customDomains.domainName) {

					function CustomDomainOnFrontDoorEnableHttps {
						param(
							$CustomDomainsObject
						)

						if (!$CustomDomainsObject.customCertificateSecretName) {

							Write-Verbose "Enabling TLS with Azure Frontdoor managed certificates on Domain: $($CustomDomainsObject.domainName)..."

							Enable-AzFrontDoorCustomDomainHttps `
								-ResourceGroupName $frontdoorRG `
								-FrontDoorName $SettingsObject.frontdoor.name `
								-FrontendEndpointName $CustomDomainsObject.domainName.replace('.', '-') `
								-MinimumTlsVersion "1.2"
						}
						else {

							Write-Verbose "Enabling TLS with Azure custom certificates on Domain: $($CustomDomainsObject.domainName)..."

							Enable-AzFrontDoorCustomDomainHttps `
								-ResourceGroupName $frontdoorRG `
								-FrontDoorName $SettingsObject.frontdoor.name `
								-FrontendEndpointName $CustomDomainsObject.domainName.replace('.', '-')`
								-Vault $CustomDomainsObject.vaultService.ResourceId `
								-SecretName $CustomDomainsObject.customCertificateSecretName `
								-SecretVersion $CustomDomainsObject.customCertificateSecretVersion `
								-MinimumTlsVersion "1.2"

						}
					}

					$customDomainStatus = Get-AzFrontDoorFrontendEndpoint -FrontDoorName $SettingsObject.frontdoor.name -ResourceGroupName $frontdoorRG

					$SettingsObject.frontDoor.customDomains | Where-Object { $_.enableHttps -eq $true } | forEach-Object {

						if ($_.customCertificateSecretName) {

							Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "keyvault" -ResourceServiceContainer $_ -Isdependency
							$_.vaultService = Get-CmAzService -Service $_.service.dependencies.keyvault -ThrowIfUnavailable -ThrowIfMultiple

							if (!$_.customCertificateSecretVersion) {
								$_.customCertificateSecretVersion = (Get-AzKeyVaultSecret -VaultName $_.vaultService.Name -Name $_.customCertificateSecretName).Version
							}
						}

						$domainName = $_.domainName

						if (($customDomainStatus | Where-Object { $_.Hostname -eq $domainName }).CustomHttpsProvisioningState -eq "Disabled") {
							CustomDomainOnFrontDoorEnableHttps -CustomDomainsObject $_
						}
						else {
							Write-Verbose "$($_.domainName) already has TLS enabled and certificates deployed..."
							$customDomainStatus | Where-Object { $_.Hostname -eq $domainName }
						}
					}
				}
			}

			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupsToSet

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}
}