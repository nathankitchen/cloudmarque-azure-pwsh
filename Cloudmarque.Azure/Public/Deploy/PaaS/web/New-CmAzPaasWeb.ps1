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

		$commandName = $MyInvocation.MyCommand.Name

		Write-CommandStatus -CommandName $commandName

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName $commandName

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Azure - Frontdoor | Backendpool | Webapps along with routing rules")) {

			$azContext = Get-AzContext

			$applicationInstrumentationKey = ""

			if ($SettingsObject.service.dependencies.appInsights) {

				Write-Verbose "Fetching appinsights instrumentation key..."
				$appInsightsService = Get-CmAzService -Service $SettingsObject.service.dependencies.appInsights -ThrowIfUnavailable -ThrowIfMultiple
				$appInsights = Get-AzApplicationInsights -ResourceGroupName $appInsightsService.resourceGroupName -Name $appInsightsService.name

				$applicationInstrumentationKey = $appInsights.InstrumentationKey
			}

			[System.Collections.ArrayList]$resourceGroupsToSet = @()
			[System.Collections.ArrayList]$functionAppSolutions = @()

			function New-ResourceGroup() {

				param(
					$resourceGroupName,
					$ResourceServiceContainer,
					$GlobalServiceContainer,
					$Location,
					$ServiceKey
				)

				$generatedResourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Location $Location -Name $resourceGroupName

				Set-GlobalServiceValues -GlobalServiceContainer $GlobalServiceContainer -ServiceKey $serviceKey -ResourceServiceContainer $ResourceServiceContainer > $null
				New-AzResourceGroup -ResourceGroupName $generatedResourceGroupName -Location $Location -Tag @{ "cm-service" = $ResourceServiceContainer.service.publish.resourceGroup } -Force > $null

				$resourceGroupsToSet.Add($generatedResourceGroupName) > $Null

				return $generatedResourceGroupName
			}

			# Crawl across SettingsObject and create defined webapps

			foreach ($webSolution in $SettingsObject.WebSolutions) {

				if ($webSolution.AppServicePlans.location.count -gt 1) {
					$location = $webSolution.AppServicePlans[0].location
				}
				else {
					$location = $webSolution.AppServicePlans.location
				}

				if (!$location) {
					if ($webSolution.apiManagementServices.location.count -gt 1) {
						$location = $webSolution.apiManagementServices[0].location
					}
					else {
						$location = $webSolution.apiManagementServices.location
					}
				}

				$webSolution.generatedResourceGroupName = New-ResourceGroup `
					-ResourceGroupName $webSolution.Name `
					-GlobalServiceContainer $SettingsObject `
					-ResourceServiceContainer $webSolution `
					-Location $location `
					-ServiceKey "resourceGroup"

				if ($webSolution.AppServicePlans) {

					foreach ($appServicePlan in $webSolution.AppServicePlans) {

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "appServicePlan" -ResourceServiceContainer $appServicePlan

						$appServicePlan.templateName = Get-CmAzResourceName -Resource "deployment" -Architecture "PaaS" -Location $appServicePlan.location -Name "$commandName-$($appServicePlan.name)"
						$appServicePlan.name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture "PaaS" -Location $appServicePlan.location -Name $appServicePlan.name

						if (!$appServicePlan.kind) {
							$appServicePlan.kind = "linux"
						}

						$appServicePlan.resourceGroupName = $webSolution.generatedResourceGroupName

						if ($appServicePlan.functions) {

							$functionAppSolutions.add(
								@{
									name            = $webSolution.Name
									service         = $webSolution.service
									transFrmWeb     = $true
									appServicePlans = @(
										@{
											resourceGroupName = $webSolution.generatedResourceGroupName
											name              = $appServicePlan.name
											functions         = $appServicePlan.functions
											sku               = $appServicePlan.sku
											location          = $appServicePlan.location
											kind              = $appServicePlan.kind
											service           = $appServicePlan.service
										}
									)
								}
							) > $Null
						}

						foreach ($webapp in $appServicePlan.webapps) {

							Write-Verbose "Generating Object for deployment of webapp : $($webapp.name)..."

							if (!$webapp.location) {
								$webapp.location = $appServicePlan.location
							}

							$webapp.webAppGeneratedName = Get-CmAzResourceName -Resource "WebApp" -Architecture "PaaS" -Location $webapp.location -Name $webapp.name

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

									if ($slotObject.name -eq "production" -and $slot.privateEndpoints) {

										Write-Error "Production is reserved slot name and cannot be used with private endpoints" -Category InvalidData -TargetObject $slotObject.name
									}

									foreach ($endpoint in $slot.privateEndpoints) {

										$endpoint.subResourceName = "sites-$($slotObject.name)"
										$endpoint.location = $webapp.location
										$endpoint.service ??= @{ dependencies = @{ resource = $webapp.service.publish.webapp } }
										$endpoint.service.dependencies.resource ??= $webapp.service.publish.webapp
									}

									Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "slot" -ResourceServiceContainer $slotObject

									Write-Verbose "Adding slot $($slotObject.name) to webapp $($webapp.Name)..."
									$webapp.slotsObject.Add($slotObject) > $null
								}
							}

							if ($webapp.contentDeliveryNetwork.Name) {

								$webapp.contentDeliveryNetwork.Name = Get-CmAzResourceName -Resource "CdnProfile" -Architecture "PaaS" -Location $webapp.contentDeliveryNetwork.location -Name $webapp.contentDeliveryNetwork.Name

								Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "cdn" -ResourceServiceContainer $webapp.contentDeliveryNetwork
								Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "endpoint" -ResourceServiceContainer $webapp.contentDeliveryNetwork
							}
							else {
								$webapp.contentDeliveryNetwork = @{
									name     = "none";
									sku      = "standard_microsoft";
									location = "global";
									service  = @{
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

				if ($webSolution.ApiManagementServices) {

					$webSolution.ApiManagementServices | forEach-Object {

						Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "apiManagement" -ResourceServiceContainer $_

						$_.resourceGroupName = $webSolution.generatedResourceGroupName

						if (!$_.skucount) {
							$_.skucount = 1
						}

						$_.templateName = Get-CmAzResourceName -Resource "deployment" -Architecture "PaaS" -Location $_.location -Name "$commandName-$($_.Name)"
						$_.generatedName = Get-CmAzResourceName -Resource "APImanagementServiceInstance" -Architecture "PaaS" -Location $_.location -Name $_.Name
					}
				}
			}

			if ($SettingsObject.WebSolutions.appServicePlans) {

				if ($SettingsObject.WebSolutions.AppServicePlans.location.count -gt 1) {
					$location = $SettingsObject.WebSolutions.AppServicePlans[0].location
				}
				else {
					$location = $SettingsObject.WebSolutions.AppServicePlans.location
				}

				[System.Collections.ArrayList]$AppServiceDetails = @()
				$AppServiceDetails += $SettingsObject.WebSolutions.AppServicePlans

				Write-Verbose "Deploying Webapps..."

				$deploymentNameWeb = Get-CmAzResourceName -Resource "Deployment" -Location $location -Architecture "PaaS" -Name "$commandName-WebApp"

				New-AzDeployment  `
					-Name $deploymentNameWeb `
					-Location $location `
					-TemplateFile "$PSScriptRoot\New-CmAzPaasWeb-Webapp.json" `
					-TemplateParameterObject @{
						AppServiceDetails = $AppServiceDetails
					}

				if ($SettingsObject.WebSolutions.appServicePlans.functions) {

					$functionSettingsObject = @{
						service              = @{
							publish      = @{
								resourceGroup  = $SettingsObject.service.publish.resourceGroup
								appServicePlan = $SettingsObject.service.publish.appServicePlan
								function       = $SettingsObject.service.publish.function
							}
							dependencies = @{
								appInsights = $SettingsObject.service.dependencies.appInsights
								storage     = $SettingsObject.service.dependencies.storage
							}
						}
						functionAppSolutions = $functionAppSolutions
					}

					New-CmAzPaasFunction -SettingsObject $functionSettingsObject -OmitTags
				}

				if ($SettingsObject.WebSolutions.appServicePlans.webapps.privateEndpoints) {

					Write-Verbose "Building private endpoints for webapps..."
					Build-PrivateEndpoints -SettingsObject @{ webapps = $SettingsObject.WebSolutions.appServicePlans.Webapps } `
						-LookupProperty "webapps" `
						-ResourceName "webapp" `
						-GlobalServiceContainer $SettingsObject.service `
						-GlobalSubResourceName "sites" `
						-GlobalResourceNameSpace "Microsoft.Web/sites"
				}

				if ($SettingsObject.WebSolutions.appServicePlans.webapps.slots.privateEndpoints) {

					Write-Verbose "Building private endpoints for webapp slots..."
					Build-PrivateEndpoints -SettingsObject @{ slots = $SettingsObject.WebSolutions.appServicePlans.Webapps.Slots } `
						-LookupProperty "slots" `
						-ResourceName "slot" `
						-GlobalServiceContainer $SettingsObject.service `
						-GlobalResourceNameSpace "Microsoft.Web/sites"
				}
			}

			if ($SettingsObject.WebSolutions.ApiManagementServices) {

				if ($SettingsObject.WebSolutions.ApiManagementServices.location.count -gt 1) {
					$location = $SettingsObject.WebSolutions.ApiManagementServices[0].location
				}
				else {
					$location = $SettingsObject.WebSolutions.ApiManagementServices.location
				}

				[System.Collections.ArrayList]$ApiManagementServices = @()
				$ApiManagementServices += $SettingsObject.WebSolutions.ApiManagementServices

				Write-Verbose "Deploying api management services..."

				$deploymentNameApim = Get-CmAzResourceName -Resource "Deployment" -Location $location -Architecture "PaaS" -Name "$commandName-ApiMs"

				New-AzDeployment `
					-Name $deploymentNameApim `
					-Location $location `
					-TemplateFile "$PSScriptRoot\New-CmAzPaasWeb-ApiManagementServices.json" `
					-TemplateParameterObject @{
						ApiManagementServices = $ApiManagementServices
					}
			}


			if ($SettingsObject.frontdoor) {

				# Frontdoor configuration:
				$frontendEndpointObjectArray = [System.Collections.ArrayList]@()

				$frontdoorRG = New-ResourceGroup `
					-ResourceGroupName $SettingsObject.frontdoor.name `
					-GlobalServiceContainer $SettingsObject `
					-ResourceServiceContainer $SettingsObject.frontdoor `
					-Location $SettingsObject.frontdoor.location `
					-ServiceKey "frontDoorResourceGroup"

				Write-Verbose "Initiating compilation of Frontends..."

				$frontdoorSuppliedHostName = $SettingsObject.frontdoor.name
				$SettingsObject.frontdoor.name = Get-CmAzResourceName -Resource "FrontDoor" -Architecture "PaaS" -Location $SettingsObject.frontdoor.location -Name $SettingsObject.frontdoor.name

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

					if (!$routingRule.endpoints) {
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
					}
					else {
						$routingRule.cacheConfiguration = $null
					}
				}

				Write-Verbose "Deploying Frontdoor..."

				$deploymentNameFd = Get-CmAzResourceName -Resource "Deployment" -Location "Global" -Architecture "PaaS" -Name "$commandName-Fd"

				New-AzResourceGroupDeployment  `
					-Name $deploymentNameFd `
					-ResourceGroupName $frontdoorRG `
					-TemplateFile "$PSScriptRoot\New-CmAzPaasWeb-Frontdoor.json" `
					-TemplateParameterObject @{
						Frontdoor = $SettingsObject.frontdoor
					    FrontdoorService = $SettingsObject.service.publish.frontDoor
					}

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

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}
}