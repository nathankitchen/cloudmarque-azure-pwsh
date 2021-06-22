function New-CmAzPaasFunction {

    <#
		.Synopsis
		 Create Azure fuctions

		.Description
		 Completes following:
            * Creates App service plan
            * Creates Consumption type app service plan (serverless)
			* Creates function on service plans
			* Optional App insights

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
         File path for the tag settings file to be converted into a tag settings object.

        .Parameter OmitTags
		 Parameter to specify if the cmdlet should handle its own tagging.

		.Component
		 PaaS

		.Example
		 New-CmAzPaasFunction -SettingsFile ./functions.yml

		.Example
		 New-CmAzPaasFunction -SettingsObject $settings

		.Example
		 New-CmAzPaasFunction -SettingsObject $settings -TagSettingFile ./tag.yml
	#>

    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        [String]$TagSettingsFile,
        [Switch]$OmitTags
    )

    $ErrorActionPreference = "Stop"

    try {

        Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

        $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Azure Functions")) {

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
                    $Location,
                    $ServiceKey
                )

                $generatedResourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Location $Location -Name $resourceGroupName

                Set-GlobalServiceValues -GlobalServiceContainer $GlobalServiceContainer -ServiceKey $serviceKey -ResourceServiceContainer $ResourceServiceContainer > $null
                New-AzResourceGroup -ResourceGroupName $generatedResourceGroupName -Location $Location -Tag @{ "cm-service" = $ResourceServiceContainer.service.publish.resourceGroup } -Force > $null

                $resourceGroupsToSet.Add($generatedResourceGroupName) > $Null

                return $generatedResourceGroupName
            }

            foreach ($functionAppSolution in $SettingsObject.functionAppSolutions) {

                if ($functionAppSolution.AppServicePlans.location.count -gt 1) {
                    $location = $functionAppSolution.AppServicePlans[0].location
                }
                else {
                    $location = $functionAppSolution.AppServicePlans.location
                }

                if (!$location) {

                    if ($functionAppSolution.ConsumptionPlans.location.count -gt 1) {
                        $location = $functionAppSolution.ConsumptionPlans[0].location
                    }
                    else {
                        $location = $functionAppSolution.ConsumptionPlans.location
                    }
                }

                $functionAppSolution.transFrmWeb ??= $false

                if (!$functionAppSolution.transFrmWeb) {

                    $functionAppSolution.generatedResourceGroupName = New-ResourceGroup `
                        -ResourceGroupName $functionAppSolution.Name `
                        -GlobalServiceContainer $SettingsObject `
                        -ResourceServiceContainer $functionAppSolution `
                        -Location $location `
                        -ServiceKey "resourceGroup"
                }

                if ($functionAppSolution.AppServicePlans) {

                    Write-Verbose "AppServicePlan found.."

                    foreach ($appServicePlan in $functionAppSolution.AppServicePlans) {

                        Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "appServicePlan" -ResourceServiceContainer $appServicePlan

                        if (!$functionAppSolution.transFrmWeb) {

                            $appServicePlan.name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture "PaaS" -Location $appServicePlan.location -Name $appServicePlan.name
                            $appServicePlan.resourceGroupName = $functionAppSolution.generatedResourceGroupName
                        }

                        $appServicePlan.exists = $functionAppSolution.transFrmWeb
                        $appServicePlan.reserved = $appServicePlan.kind -eq 'linux' ? $true : $false

                        foreach ($function in $appServicePlan.functions) {

                            Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "storage" -ResourceServiceContainer $function -IsDependency

                            $function.location ??= $appServicePlan.location
                            $function.storageAccount = Get-CmAzService -Service $function.service.dependencies.storage -Location $function.location -ThrowIfUnavailable -ThrowIfMultiple

                            Write-Verbose "$($function.name): Generating Object for deployment of function"

                            $function.linuxFxVersion = $appServicePlan.kind -eq 'linux' ? $function.runtime : ""

                            $function.kind = "functionapp"
                            $function.name = Get-CmAzResourceName -Resource "FunctionApp" -Architecture "PaaS" -Location $function.location -Name $function.name
                            $function.functionsWorker = $function.runtime.split('|')

                            $function.applicationInstrumentationKey = $function.enableAppInsight ? $applicationInstrumentationKey : ''

                            Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "function" -ResourceServiceContainer $function

                            # Required to support private endpoints
                            $function.service.publish.resourceGroup = $functionAppSolution.service.publish.resourceGroup
                        }
                    }
                }

                if ($functionAppSolution.ConsumptionPlans) {

                    Write-Verbose "Consumption Plan found.."

                    foreach ($function in $functionAppSolution.ConsumptionPlans) {

                        Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "storage" -ResourceServiceContainer $function -IsDependency

                        $function.storageAccount = Get-CmAzService -Service $function.service.dependencies.storage -Location $function.location -ThrowIfUnavailable -ThrowIfMultiple
                        $function.storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $function.storageAccount.resourceGroupName -Name $function.storageAccount.Name).Value[0]

                        Write-Verbose "$($function.name): Generating Object for deployment of function"

                        $function.resourceGroupName = $functionAppSolution.generatedResourceGroupName
                        $function.planName = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture "PaaS" -Location $function.location -Name $function.name
                        $function.name = Get-CmAzResourceName -Resource "FunctionApp" -Architecture "PaaS" -Location $function.location -Name $function.name
                        $function.functionsWorker = $function.runtime.split('|')

                        if ($function.kind -eq "linux") {
                            $function.kind = "functionapp,linux"
                            $function.appServiceKind = "linux"
                        }
                        else {
                            $function.kind = "functionapp"
                            $function.appServiceKind = ""
                        }

                        Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "appServicePlan" -ResourceServiceContainer $function
                        Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "function" -ResourceServiceContainer $function
                        $function.applicationInstrumentationKey = $function.enableAppInsight ? $applicationInstrumentationKey : ''
                    }
                }
            }

            if ($SettingsObject.functionAppSolutions.AppServicePlans) {

                $location = $SettingsObject.functionAppSolutions.AppServicePlans.location.count -gt 1 ? $SettingsObject.functionAppSolutions.AppServicePlans[0].location : $SettingsObject.functionAppSolutions.AppServicePlans.location

                Write-Verbose "Deploying functions on app service plans..."

                $deploymentNameAsp = Get-CmAzResourceName -Resource "Deployment" -Architecture "PaaS" -Location $location -Name "New-CmAzPaasFunction"

                New-AzDeployment `
                    -Name $deploymentNameAsp `
                    -Location $location `
                    -TemplateFile "$PSScriptRoot\New-CmAzPaasFunction.AppServicePlan.json" `
                    -AppServicePlans $SettingsObject.functionAppSolutions.AppServicePlans

                if ($SettingsObject.functionAppSolutions.appServicePlans.functions.privateEndpoints) {

                    Write-Verbose "Building private endpoints for function in appservice plan..."
                    Build-PrivateEndpoints -SettingsObject @{ functions = $SettingsObject.functionAppSolutions.appServicePlans.functions } `
                        -LookupProperty "functions" `
                        -ResourceName "function" `
                        -GlobalServiceContainer $SettingsObject.service `
                        -GlobalSubResourceName "sites"
                }
            }

            if ($SettingsObject.functionAppSolutions.ConsumptionPlans) {

                $location = $SettingsObject.functionAppSolutions.ConsumptionPlans.location.count -gt 1 ? $SettingsObject.functionAppSolutions.ConsumptionPlans[0].location : $SettingsObject.functionAppSolutions.ConsumptionPlans.location

                Write-Verbose "Deploying functions on consumption plans..."

                $deploymentNameCon = Get-CmAzResourceName -Resource "Deployment" -Architecture "PaaS" -Location $location -Name "New-CmAzPaasFunction"

                New-AzDeployment `
                    -Name $deploymentNameCon `
                    -Location $location `
                    -TemplateFile "$PSScriptRoot\New-CmAzPaasFunction.Consumption.json" `
                    -ConsumptionPlans $SettingsObject.functionAppSolutions.ConsumptionPlans
            }

            if (!$OmitTags) {

                Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupsToSet
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSitem);
    }
}