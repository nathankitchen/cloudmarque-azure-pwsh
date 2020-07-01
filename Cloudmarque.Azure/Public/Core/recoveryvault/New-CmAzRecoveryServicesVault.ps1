function New-CmAzRecoveryServicesVault {
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

        .Component
         Core

        .Example
         New-CmAzRecoveryServicesVault -SettingsFile C:\ProjectDirectory\RecoveryServicesVault.yml

        .Example
         New-CmAzRecoveryServicesVault -SettingsFile C:\ProjectDirectory\RecoveryServicesVault.yml -PolicySettingsFile C:\ProjectDirectory\RecoveryServicesPolicy.yml

        .Example
         New-CmAzRecoveryServicesVault -SettingsFile C:\ProjectDirectory\RecoveryServicesVault.yml -PolicySettingsObject $policies

        .Example
         New-CmAzRecoveryServicesVault -SettingsObject $settings

        .Example
         New-CmAzRecoveryServicesVault -SettingsObject $settings -PolicySettingsFile C:\ProjectDirectory\RecoveryServicesPolicy.yml

        .Example
         New-CmAzRecoveryServicesVault -SettingsObject $settings -PolicySettingsObject $policies
	#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    [OutputType([Hashtable])]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        [String]$PolicySettingsFile,
        [Object]$PolicySettingsObject
    )

    $ErrorActionPreference = "Stop"

    if ($SettingsFile -and !$SettingsObject) {
        Write-Verbose "Gathering details from settings file ($($SettingsFile))"
        $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
    }
    elseif (!$SettingsFile -and !$SettingsObject) {
        Throw "No valid input settings"
    }

    if ($PolicySettingsFile -and !$PolicySettingsObject) {
        Write-Verbose "Gathering policy details from settings file ($($PolicySettingsFile))"
        $PolicySettingsObject = Get-CmAzSettingsFile -Path $PolicySettingsFile
    }

    if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Backup Vaults")) {

        Write-Verbose "Generating standardised Resource Group Name from input: $($SettingsObject.resourceGroupName)"
        $resourceGroupName = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region $SettingsObject.location -Name $SettingsObject.resourceGroupName

        Write-Verbose "Generated standardised Resource Group Name: $resourceGroupName"
        Write-Verbose "Checking if Resource Group exists."
        if (!(Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
            Write-Verbose "Resource Group does not exist, creating."
            $ReturnResourceGroup = New-AzResourceGroup -Location $SettingsObject.location -Name $resourceGroupName -ErrorAction Stop
        }

        Write-Verbose "Generating standardised Recovery Services Vault names."
        Foreach ($vault in $SettingsObject.recoveryServicesVaults) {
            $vault.name = Get-CmAzResourceName -Resource "recoveryservicesvault" -Architecture "Core" -Region $vault.location -Name $vault.name
            Write-Verbose "Generated standardised Key Vault name: $($vault.name)"
        }

        $workspace = Get-CmAzService -Service 'core.loganalytics1' -Region $SettingsObject.Location -ThrowIfUnavailable

        Write-Verbose "Deploying Azure ARM template for Recovery Services Vaults."
        $ReturnRecoveryServicesVault = New-AzResourceGroupDeployment `
            -ResourceGroupName $resourceGroupName `
            -TemplateFile "$PSScriptRoot\New-CmAzRecoveryServicesVault.json" `
            -RecoveryServicesVaults $SettingsObject.recoveryServicesVaults `
            -WhatIf:$WhatIfPreference
        Write-Verbose "Completed."

        Write-Verbose "Deploying Azure ARM template for Recovery Services Diagnostics."
        Foreach ($vault in $SettingsObject.recoveryServicesVaults) {
            $ReturnRecoveryServicesPolicy = New-AzResourceGroupDeployment `
                -ResourceGroupName $resourceGroupName `
                -TemplateFile "$PSScriptRoot\New-CmAzRecoveryServicesDiagnostics.json" `
                -VaultName $vault.name `
                -Workspace $workspace `
                -WhatIf:$WhatIfPreference
        }
        Write-Verbose "Completed."

        if ($PolicySettingsObject) {

            Write-Verbose "Deploying Azure ARM template for Recovery Services Policies."
            Foreach ($vault in $SettingsObject.recoveryServicesVaults) {
                $ReturnRecoveryServicesPolicy = New-AzResourceGroupDeployment `
                    -ResourceGroupName $resourceGroupName `
                    -TemplateFile "$PSScriptRoot\New-CmAzRecoveryServicesPolicy.json" `
                    -VaultName $vault.name `
                    -PolicyObject $PolicySettingsObject `
                    -WhatIf:$WhatIfPreference
            }
            Write-Verbose "Completed."
        }
    }
    return @{
        ResourceGroup          = $ReturnResourceGroup
        RecoveryServicesVault  = $ReturnRecoveryServicesVault
        RecoveryServicesPolicy = $ReturnRecoveryServicesPolicy
    }
}