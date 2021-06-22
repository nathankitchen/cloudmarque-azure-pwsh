function New-CmAzIaasRecoveryServicesVault {

    <#
        .Synopsis
         Creation of Azure Recovery Services Vault.

        .Description
         Creation of Azure Recovery Services Vault from a YAML settings file, with the additional option of attaching Backup Policies also using a YAML settings file.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

        .Parameter PolicySettingsFile
         The full path to the settings file (YAML), e.g. C:\ProjectDirectory\RecoveryServicesPolicy.yml

        .Parameter PolicySettingsObject
         The object representing the policy settings for this cmdlet.

        .Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

        .Component
         IaaS

        .Example
         New-CmAzIaasRecoveryServicesVault -SettingsFile C:\ProjectDirectory\RecoveryServicesVault.yml

        .Example
         New-CmAzIaasRecoveryServicesVault -SettingsFile C:\ProjectDirectory\RecoveryServicesVault.yml -PolicySettingsFile C:\ProjectDirectory\RecoveryServicesPolicy.yml

        .Example
         New-CmAzIaasRecoveryServicesVault -SettingsFile C:\ProjectDirectory\RecoveryServicesVault.yml -PolicySettingsObject $policies

        .Example
         New-CmAzIaasRecoveryServicesVault -SettingsObject $settings

        .Example
         New-CmAzIaasRecoveryServicesVault -SettingsObject $settings -PolicySettingsFile C:\ProjectDirectory\RecoveryServicesPolicy.yml

        .Example
         New-CmAzIaasRecoveryServicesVault -SettingsObject $settings -PolicySettingsObject $policies
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    [OutputType([Hashtable])]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        [String]$PolicySettingsFile,
        [Object]$PolicySettingsObject,
        [String]$TagSettingsFile
    )

    $ErrorActionPreference = "Stop"

    Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

    $cmdletName = Get-CurrentCmdletName -ScriptRoot $PSCommandPath

    $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName $cmdletName
    $PolicySettingsObject = Get-Settings -SettingsFile $PolicySettingsFile -SettingsObject $PolicySettingsObject -CmdletName "New-CmAzIaasRecoveryServicesPolicy"

    if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Backup Vaults")) {


        Write-Verbose "Generating standardised Resource Group Name from input: $($SettingsObject.resourceGroupName)"
        $resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "IaaS" -Location $SettingsObject.location -Name $SettingsObject.resourceGroupName

        Write-Verbose "Generated standardised Resource Group Name: $resourceGroupName"
        Write-Verbose "Checking if Resource Group exists."

        $existingResourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

        if (!$existingResourceGroup) {
            Write-Verbose "Resource Group does not exist, creating."
            $resourceGroupServiceTag = @{ "cm-service" = $SettingsObject.service.publish.resourceGroup }
            New-AzResourceGroup -Location $SettingsObject.location -Name $resourceGroupName -Tag $resourceGroupServiceTag -Force
        }

        Write-Verbose "Generating standardised Recovery Services Vault names."
        Foreach ($vault in $SettingsObject.recoveryServicesVaults) {

            $vault.managedIdentity = $vault.managedIdentity ? "SystemAssigned" : "None"
            $vault.name = Get-CmAzResourceName -Resource "recoveryservicesvault" -Architecture "IaaS" -Location $vault.location -Name $vault.name
            Write-Verbose "Generated standardised Key Vault name: $($vault.name)"

            Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "recoveryVault" -ResourceServiceContainer $vault
        }

        $workspace = Get-CmAzService -Service $SettingsObject.service.dependencies.workspace -Location $SettingsObject.location -ThrowIfUnavailable -ThrowIfMultiple

        Write-Verbose "Deploying Azure ARM template for Recovery Services Vaults..."

        $deploymentNameRv = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.location -Name "New-CmAzIaasRecoveryServicesVault"

        New-AzResourceGroupDeployment `
            -Name $deploymentNameRv `
            -ResourceGroupName $resourceGroupName `
            -TemplateFile "$PSScriptRoot\New-CmAzIaasRecoveryServicesVault.json" `
            -RecoveryServicesVaults $SettingsObject.recoveryServicesVaults `
            -Force

        Write-Verbose "Deploying Recovery Services Diagnostics..."
        Foreach ($vault in $SettingsObject.recoveryServicesVaults) {

            $deploymentNameRvSd = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.location -Name "New-CmAzIaasRecoveryServicesVault-Sd"

            New-AzResourceGroupDeployment `
                -Name $deploymentNameRvSd `
                -ResourceGroupName $resourceGroupName `
                -TemplateFile "$PSScriptRoot\New-CmAzIaasRecoveryServicesDiagnostics.json" `
                -VaultName $vault.name `
                -Workspace $workspace `
                -Force
        }

        if ($PolicySettingsObject) {

            Write-Verbose "Deploying Recovery Services Policies..."
            Foreach ($vault in $SettingsObject.recoveryServicesVaults) {

                $deploymentNameRvSp = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Location $SettingsObject.location -Name "New-CmAzIaasRecoveryServicesVault-Sp"

                New-AzResourceGroupDeployment `
                    -Name $deploymentNameRvSp `
                    -ResourceGroupName $resourceGroupName `
                    -TemplateFile "$PSScriptRoot\New-CmAzIaasRecoveryServicesPolicy.json" `
                    -VaultName $vault.name `
                    -Policies $PolicySettingsObject.policies
            }
        }

        if ($SettingsObject.recoveryServicesVaults.privateEndpoints){

            Write-Verbose "Building private endpoints..."
            Build-PrivateEndpoints -SettingsObject $SettingsObject -LookupProperty "recoveryServicesVaults" -ResourceName "recoveryVault" -GlobalSubResourceName "vault"
        }

        if ($existingResourceGroup) {
            Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $SettingsObject.recoveryServicesVaults.name
        }
        else {
            Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupName
        }
    }
}