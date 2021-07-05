function New-CmAzPaaSWebStatic {

	<#
		.Synopsis
		 Deploys a static website utilising a CDN and Blob Storage.

		.Description
		 Completes the following:
		 	* Deploys a ResourceGroup, CDNProfile, Storage account and Endpoint with their details set via the Settings object or file.
		 	* Sets the endpoint to allow static websites.
		 	* Sets CDN rules.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 An object including all the properties required to configure the target website, with a structure following the same convention
		 as the YAML file. This allows properties to be dynamically generated rather than simply loaded from a file.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Component
		 PaaS

		.Example
		 New-CmAzPaaSWebStatic -SettingsFile "/mysite/paas.web.static.mysite.yml"

		 Creates a new static website using settings from the specified YML file.

		.Example
		 New-CmAzPaaSWebStatic -SettingsObject $settings

		.Example
		 /mysite/paas.web.static.mysite.yml
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	[OutputType([Hashtable])]
    param(
      [parameter(Mandatory=$true, ParameterSetName = "Settings File")]
      [String]$SettingsFile,
      [parameter(Mandatory=$true, ParameterSetName = "Settings Object")]
      [Object]$SettingsObject,
	  [String]$TagSettingsFile
    )

	$ErrorActionPreference = "Stop"

	Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

	$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

	if($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy infrastructure for a static website")) {

		Write-Verbose "Generating resource names..."
		$resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Location $SettingsObject.Location -Name $SettingsObject.Name
		$profileName = Get-CmAzResourceName -Resource "CdnProfile" -Architecture "PaaS" -Location $SettingsObject.Location -Name $SettingsObject.Name
		$endpointName = Get-CmAzResourceName -Resource "Endpoint" -Architecture "PaaS" -Location $SettingsObject.Location -Name $SettingsObject.Name

		Write-Verbose "Deploying resource group: $resourceGroupName..."
		$resourceGroupServiceTag = @{ "cm-service" = $SettingsObject.service.publish.resourceGroup }
		New-AzResourceGroup -Name $resourceGroupName -Location $SettingsObject.Location -Tag $resourceGroupServiceTag -Force > $null

		$providerNamespace = "Microsoft.CDN"

		if ((Get-AzResourceProvider -Location $SettingsObject.Location -ProviderNamespace $providerNamespace | Where-Object { $_.RegistrationState -ne "Registered" }).Count -gt 0)
		{
			Register-AzResourceProvider -ProviderNamespace $providerNamespace
		}

		Write-Verbose "Deploying storage account..."
		$storageObject = @{
			location = $SettingsObject.Location;
			service = @{
				dependencies = @{
					ResourceGroup = $SettingsObject.service.publish.resourceGroup
				};
				publish = @{
					storage = $SettingsObject.service.publish.storage
				}
			}
			storageAccounts = @(@{
				storageAccountName = $SettingsObject.Name;
				accountType = "Standard";
				blobContainer = @(@{
						name = "`$web";
						publicAccess = "blob"
					}
				)
			})
		}

		Write-Verbose "Creating storage account..."
		New-CmAzIaasStorage -SettingsObject $storageObject -OmitTags > $null

		$storageName = Get-CmAzResourceName -Resource "StorageAccount" -Architecture "IaaS" -Location $SettingsObject.Location -Name $SettingsObject.Name

		Write-Verbose "Deploying cdn: $profileName..."

		$deploymentNameCdn = Get-CmAzResourceName -Resource "Deployment" -Location $SettingsObject.Location -Architecture "PaaS" -Name "New-CmAzPaasWebStatic-cdn"

		New-AzResourceGroupDeployment `
			-Name $deploymentNameCdn `
			-ResourceGroupName $resourceGroupName `
			-TemplateFile "$PSScriptRoot/New-CmAzPaasWebStatic.Cdn.json" `
			-StorageName $storageName `
			-EndpointName $endpointName `
			-ProfileName $profileName `
			-ServiceContainer $SettingsObject.service.publish `
			-Force > $null

		Write-Verbose "Writng cdn rules..."
		$ruleOrder = 0
		$cdnRules = @()

		$rpAction = New-AzCdnDeliveryRuleAction -HeaderActionType ModifyResponseHeader -Action Append -HeaderName "referrer-policy" -Value "strict-origin-when-cross-origin"
		$cspAction = New-AzCdnDeliveryRuleAction -HeaderActionType ModifyResponseHeader -Action Append -HeaderName "content-security-policy" -Value "default-src https: 'self' *"
		$fpAction = New-AzCdnDeliveryRuleAction -HeaderActionType ModifyResponseHeader -Action Append -HeaderName "feature-policy" -Value "camera 'none'; geolocation 'none'; microphone 'none'; payment 'none' usb 'none'"
		$globalRule = New-AzCdnDeliveryRule -Name "Global" -Order $ruleOrder -Action $rpAction, $cspAction, $fpAction

		if ($SettingsObject.RedirectPublicIpAddress) {

			$ruleOrder++

			# Only apply conditions and rules for provided ipAddress
			$ipRedirectCondition = New-AzCdnDeliveryRuleCondition -MatchVariable RemoteAddress -Operator IPMatch -MatchValue $SettingsObject.RedirectPublicIpAddress -NegateCondition
			$ipRedirectAction = New-AzCdnDeliveryRuleAction -RedirectType Found -CustomHostname $SettingsObject.RedirectUrl -CustomPath "/"
			$ipRedirectRule = New-AzCdnDeliveryRule -Name "IPRedirect" -Order $ruleOrder -Condition $ipRedirectCondition -Action $ipRedirectAction

			$cdnRules += $ipRedirectRule
		}

		$ruleOrder++

		$httpRedirectCondition = New-AzCdnDeliveryRuleCondition -MatchVariable RequestScheme -Operator Equal -MatchValue "HTTP"
		$httpRedirectAction = New-AzCdnDeliveryRuleAction -RedirectType Found -CustomHostname $SettingsObject.CustomDomain -DestinationProtocol "Https"
		$httpRedirectRule = New-AzCdnDeliveryRule -Name "HttpRedirectRule" -Order $ruleOrder -Condition $httpRedirectCondition -Action $httpRedirectAction

		$ruleOrder++

		$canonicalPathCondition = New-AzCdnDeliveryRuleCondition -MatchVariable UrlFileName -Operator Equal -MatchValue "index"
		$canonicalPathRedirectAction = New-AzCdnDeliveryRuleAction -RedirectType Found -CustomHostname $SettingsObject.CustomDomain -CustomPath "/"
		$canonicalPathRule = New-AzCdnDeliveryRule -Name "CanonicalUrl" -Order $ruleOrder -Condition $canonicalPathCondition -Action $canonicalPathRedirectAction

		$ruleOrder++

		$anyPathCondition = New-AzCdnDeliveryRuleCondition -MatchVariable RequestScheme -Operator Equal -MatchValue "HTTPS"

		$xctoAction = New-AzCdnDeliveryRuleAction -HeaderActionType ModifyResponseHeader -Action Append -HeaderName "x-content-type-options" -Value "nosniff"
		$xfoAction = New-AzCdnDeliveryRuleAction -HeaderActionType ModifyResponseHeader -Action Append -HeaderName "x-frame-options" -Value "SAMEORIGIN"
		$stsAction = New-AzCdnDeliveryRuleAction -HeaderActionType ModifyResponseHeader -Action Append -HeaderName "strict-transport-security" -Value "max-age=31536000; includeSubDomains"
		$addHeadersRule = New-AzCdnDeliveryRule -Name "AdditonalSecurityHeaders" -Order $ruleOrder -Condition $anyPathCondition -Action $xctoAction, $xfoAction, $stsAction

		$cdnRules += @($globalRule, $addHeadersRule, $httpRedirectRule, $canonicalPathRule)

		$policy = New-AzCdnDeliveryPolicy -Description "DeliveryPolicy" -Rule $cdnRules

		Write-Verbose "Fetching storage context..."
		$storageContext = New-AzStorageContext -StorageAccountName $storageName

		Write-Verbose "Enabling static site setting..."
		Enable-AzStorageStaticWebsite -IndexDocument "index.html" -ErrorDocument404Path "404.html" -Context $storageContext > $null

		Write-Verbose "Fetching endpoint ($endpointName)..."
		$endpoint = Get-AzCdnEndpoint -EndpointName $endpointName -ProfileName $profileName -ResourceGroupName $resourceGroupName
		$endpoint.DeliveryPolicy = $policy

		Write-Verbose "Setting endpoint ($endpointName)..."
		Set-AzCdnEndpoint -CdnEndpoint $endpoint > $null

		Write-Verbose "Setting custom domain..."
		if((Test-AzCdnCustomDomain -CdnEndpoint $endpoint -CustomDomainHostName $SettingsObject.CustomDomain).CustomDomainValidated) {
			New-AzCdnCustomDomain -CustomDomainName $SettingsObject.CustomDomain -HostName $SettingsObject.CustomDomain -CdnEndpoint $endpoint -ErrorAction SilentlyContinue
		}

		Write-Verbose "Purging cdn..."
		Unpublish-AzCdnEndpointContent -EndpointName $endpointName -ProfileName $profileName -ResourceGroupName $resourceGroupName -PurgeContent "/*"

		Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupName

        Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
	}
}