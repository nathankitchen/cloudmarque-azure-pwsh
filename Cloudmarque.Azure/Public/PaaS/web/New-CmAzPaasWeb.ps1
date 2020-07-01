<#
 .Synopsis Create an Frontdoor with backing webapps

 .Description Completes following:
    * Creates Frontdoor
    * Creates Webapp and attaches to frontdoor
    * Optional API routing available

 .Parameter SettingsFile Path to configuration settings
 .Parameter SettingsObject Provide Azure Object
 .Parameter TagsSettingsObject create tags for frontdoor. This is to resolve a known bug with frontdoor.
 .Parameter TagsSettingsFile create tags for frontdoor. This is to resolve a known bug with frontdoor.

 .Component PaaS

 .Example
  New-CmAzPaasWeb -SettingsFile ./web.yml
 .Example
  New-CmAzPaasWeb -SettingsFile ./web.yml -TagsSettingsFile ./tags.yml
 .Example
  New-CmAzPaasWeb -SettingsObject $settings
 .Example
  New-CmAzPaasWeb -SettingsObject $settings -TagsSettingsObject $tagSettings

#>
function New-CmAzPaasWeb {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSPossibleIncorrectComparisonWithNull", "", Justification = "dev only, requires better implementation.")]
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        # Below variables are for fetchTags function to bypass known frontdoor tags bug
        [parameter(Mandatory = $false, ParameterSetName = "Settings File")]
        [String]$TagsSettingsFile,
        [parameter(Mandatory = $false, ParameterSetName = "Settings Object")]
        [Object]$TagsSettingsObject
    )
    process {

        try {

            if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Azure - Frontdoor | Backendpool | Webapps along with routing rules")) {

                if ($SettingsFile) {
                    $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
                }

                $resourceGroup = Get-CmAzService -Service $SettingsObject.ResourceGroupTag -Region $SettingsObject.Location -IsResourceGroup
                if(!$resourceGroup){
                    $env:nameResourceGroup = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Region $SettingsObject.location -Name $SettingsObject.resourceGroupTag
                    New-AzResourceGroup -ResourceGroupName $env:nameResourceGroup -Location $SettingsObject.location -Tag @{"cm-service" = $SettingsObject.resourceGroupTag}
                }
                else{
                    $env:nameResourceGroup = $resourceGroup.resourceGroupName
                }
                $env:PermanentPSScriptRoot = $PSScriptRoot

                if($SettingsObject.monitoring.applicationInstrumentationKey) {
                 $env:applicationInstrumentationKey = $SettingsObject.monitoring.applicationInstrumentationKey
                }else{
                    $env:applicationInstrumentationKey = "none"
                }

                function fetchTags {
                    ## This is to resolve a known bug with tags for frontdoor
                    $MandatoryTags = @("cm-owner", "cm-apps", "cm-charge", "cm-delete")

                    # Validate Settings file and set Tags hashtable
                    if ($TagsSettingsFile) {
                        $TagsSettingsObject = Get-CmAzSettingsFile -Path $TagsSettingsFile
                    }

                    foreach ($Item in $TagsSettingsObject.tags.mandatory.Keys) {
                        $check = $MandatoryTags.Contains($Item)
                        if (!$check) {
                            Write-Error "$Item is a Custom tag. Please add it to Custom section of YML" -Category InvalidData -CategoryTargetName $Item -ErrorAction Stop
                            Break
                        }
                    }

                    $tags = $TagsSettingsObject.tags.mandatory
                    $customTags = $TagsSettingsObject.tags.custom

                    foreach ($Item in $MandatoryTags) {
                        $check = $tags.$Item
                        if (!$check) {
                            Write-Error "Mandatory Tag - $Item is Null. Please set appropriate Value in settings file" -Category InvalidData -CategoryTargetName $Item -ErrorAction Stop
                        }
                        else {
                            Write-verbose "Tag - $Item will be set as $check"
                        }
                    }

                    if ($SettingsObject.tags.custom) {
                        foreach ($Item in ($customTags).Keys) {
                            $Value = $SettingsObject.tags.custom.$Item
                            Write-verbose "Tag - $Item will be set as $Value"
                        }
                    }

                    $tags = $tags + $customTags
                    $tags | Write-Verbose
                    Return $tags
                }

                if($TagsSettingsFile -or $TagsSettingsObject){
                    $frontdoorTags = fetchTags
                }else{
                    $frontdoorTags = @{}
                }

                # Crawl across SettingsObject and create defined webapps
                $SettingsObject.appServicePlans | ForEach-Object -Parallel {
                    foreach ($app in $_.webapps) {
                        write-verbose "Initiating deployment of webapp : $($app.name)"

                        $kind = "linux"
                        $linuxFxVersion = $app.runTime

                        New-AzResourceGroupDeployment  `
                            -Name "webapp-$($app.name)" `
                            -ResourceGroupName $env:nameResourceGroup `
                            -TemplateFile "$env:PermanentPSScriptRoot\New-CmAzPaasWeb.json" `
                            -WhatIf:$WhatIfPreference `
                            -webAppName $app.name `
                            -kind $kind `
                            -linuxFxVersion $linuxFxVersion  `
                            -appServicePlanName $_.name `
                            -sku $_.sku `
                            -location $_.region `
                            -stagingSlotName ($app.slots).ToArray() `
                            -appInstrumatationKey $env:applicationInstrumentationKey `
                            -Force

                        Write-Verbose "$($app.name) is created"
                    }
                }

                #  Create FrontendEndpoint Object
                $SettingsObject.apiManagementServices | foreach-object -parallel {
                    if ($_.name -and $_.region -and $_.organization -and $_.adminEmail -and $_.sku ) {
                        try {
                            write-verbose "Creating ApiManagementService $($_.name)"
                            New-AzApiManagement `
                                -ResourceGroupName $env:nameResourceGroup `
                                -Location $_.region `
                                -Name $_.name `
                                -Organization $_.organization `
                                -AdminEmail $_.adminEmail `
                                -Sku $_.sku

                            while (!(([system.uri](Get-AzApiManagement -Name $_.name -ResourceGroupName $env:nameResourceGroup).RuntimeUrl).Host)) {
                                Start-Sleep -minutes 5
                                write-verbose "waiting for API To generate URL....."
                            }
                        }
                        catch {
                            write-verbose "There was some error or the API service is already present"
                        }

                        $url = ([system.uri](Get-AzApiManagement -Name $_.name -ResourceGroupName $env:nameResourceGroup).RuntimeUrl).Host
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
                    Write-Verbose "FrontEnd Domains Are:"
                    $frontendEndpointObjectArray | Write-Verbose
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
                        $resourceType = (Get-AzResource -ResourceGroupName $env:nameResourceGroup -Name $appname -ErrorAction SilentlyContinue).ResourceType
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
                    $healthProbeSettingObject = New-AzFrontDoorHealthProbeSettingObject -Name "HealthProbeSetting-$($backEndPool.name)" -Path  $backEndPool.HealthCheckPath -Protocol $backEndPool.protocol
                    $loadBalancingSettingObject = New-AzFrontDoorLoadBalancingSettingObject -Name "Loadbalancingsetting-$($backEndPool.name)"
                    $healthProbeSettingObject | write-verbose
                    $loadBalancingSettingObject | write-verbose

                    write-verbose "creating BackendPoolObject $($backEndPool.name)"
                    write-verbose "BackendPoolObjectArray:"
                    $backendObjectArray | Write-Verbose

                    $backEndPoolObject = New-AzFrontDoorBackendPoolObject -Name $backEndPool.name `
                        -FrontDoorName $SettingsObject.frontDoor.hostName `
                        -ResourceGroupName $env:nameResourceGroup `
                        -Backend $backendObjectArray `
                        -HealthProbeSettingsName "HealthProbeSetting-$($backEndPool.name)" `
                        -LoadBalancingSettingsName "Loadbalancingsetting-$($backEndPool.name)"

                    $backEndPoolObject
                    Write-Verbose "Backend Pool Object Created for $($backEndPool.name)"

                    $backEndPoolObjectArray.Add($backEndPoolObject) > $null
                    $healthProbeSettingObjectArray.Add($healthProbeSettingObject) > $null
                    $loadBalancingSettingObjectArray.Add($loadBalancingSettingObject) > $null
                }

                foreach ($rule in $SettingsObject.frontDoor.rules) {
                    foreach ($endpointObject in $frontendEndpointObjectArray) {
                        $routingRuleObject = New-AzFrontDoorRoutingRuleObject -Name $rule.name `
                            -FrontDoorName $SettingsObject.frontDoor.hostName `
                            -ResourceGroupName $env:nameResourceGroup `
                            -FrontendEndpointName $endpointObject.Name `
                            -BackendPoolName  $rule.backEndPoolName `
                            -PatternToMatch  $rule.Pattern
                    }
                    $routingRuleObject | write-verbose
                    $routingRuleObjectArray.Add($routingRuleObject) > $null
                }
                $routingRuleObjectArray | Write-Verbose

                # Create Frontdoor
                Write-Verbose "Initiating creation of Azure frontdoor"

                New-AzFrontDoor -Name $SettingsObject.frontDoor.hostName `
                    -ResourceGroupName $env:nameResourceGroup `
                    -FrontendEndpoint $frontendEndpointObjectArray `
                    -BackendPool $backEndPoolObjectArray `
                    -HealthProbeSetting $healthProbeSettingObjectArray `
                    -LoadBalancingSetting $loadBalancingSettingObjectArray `
                    -RoutingRule $routingRuleObjectArray `
                    -Tag $frontdoorTags


                if ($SettingsObject.frontDoor.customDomains.domainName) {
                    foreach ($domain in $SettingsObject.frontDoor.customDomains) {
                        customDomainOnFrontDoorEnableHttps -domainName $domain.domainName -VaultName $domain.customCertificateVaultName -secretName $domain.customCertificateSecretName
                    }
                }

                if ($SettingsObject.contentDeliveryNetwork.name) {
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
                    $cdn = New-AzCdnProfile -ProfileName $SettingsObject.contentDeliveryNetwork.name -ResourceGroupName $env:nameResourceGroup -Sku $SettingsObject.contentDeliveryNetwork.sku -Location $SettingsObject.location | `
                        New-AzCdnEndpoint -EndpointName $SettingsObject.contentDeliveryNetwork.name -OriginName $SettingsObject.contentDeliveryNetwork.attachObjectName -OriginHostName $domain

                    $cdn | Write-Verbose
                }

                # Clean up environment
                write-verbose "Clean up environment!!"
                Remove-Item env:nameResourceGroup


                Write-Verbose "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                Write-Verbose "~~~~~~~~~~~~Finished~~~~~~~~~~~~"
                Write-Verbose "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSitem);
        }
    }
}