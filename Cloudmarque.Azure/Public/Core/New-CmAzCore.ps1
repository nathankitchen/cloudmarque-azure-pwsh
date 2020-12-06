
function New-CmAzCore {

    <#
        .Synopsis
         Helper function which wraps all the resources in Core and deploys them together.

        .Description
         Deploys a complete set of Core resources, representing a "Landing Zone" for wider deployments.
         Deploys the following:
          * Deploys Cloudmarque Monitoring solutions with action groups.
          * Deploys Automation solution for runbook and dsc.
          * Deploys Key vaults.
          * Deploys Billing rules.

        .Parameter SettingsFile
         File path for the settings file to be converted into a settings object.

        .Parameter SettingsObject
         Object containing the configuration values required to run this cmdlet.

        .Parameter TagSettingsFile
         File path for the tags settings file containing tags defination.

        .Component
         Core

        .Example
         New-CmAzCore -SettingsFile "c:/directory/settingsFile.yml"

        .Example
         New-CmAzCore -SettingsObject $settings
	#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        [AllowEmptyString()]
        [String]$TagSettingsFile
    )

    $ErrorActionPreference = "stop"

    try {

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Core Monitoring and Logging")) {

            if ($SettingsFile -and -not $SettingsObject) {
                $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
            }
            elseif (-not $SettingsFile -and -not $SettingsObject) {
                Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
            }

            $missingSettingsErrorMessage = "Please provide file path for "

            # Core Monitoring
            if (!$SettingsObject.monitorSettings) {
                Write-Error "$missingSettingsErrorMessage monitorSettings" -Category InvalidArgument -CategoryTargetName "monitorSettings"
            }

            if (!$SettingsObject.budgetSettings) {
                Write-Error "$missingSettingsErrorMessage budgetSettings" -Category InvalidArgument -CategoryTargetName "budgetSettings"
            }
            
            if (!$SettingsObject.keyvaultSettings) {
                Write-Error "$missingSettingsErrorMessage keyvaultSettings" -Category InvalidArgument -CategoryTargetName "keyvaultSettings"
            }

            if (!$SettingsObject.automationSettings) {
                Write-Error "$missingSettingsErrorMessage automationSettings" -Category InvalidArgument -CategoryTargetName "automationSettings"
            }

            Write-Verbose "Deploying core monitoring solution.."
            $SettingsObject.monitorSettings = Resolve-FilePath -NestedFile $SettingsObject.monitorSettings
            $monitorObject = Get-CmAzSettingsFile -Path $SettingsObject.monitorSettings
            New-CmAzCoreMonitor -SettingsObject $monitorObject -TagSettingsFile $TagSettingsFile

            Write-Verbose "Setting budgets.."
            $SettingsObject.budgetSettings = Resolve-FilePath -NestedFile $SettingsObject.budgetSettings
            $budgetsObject = Get-CmAzSettingsFile -Path $SettingsObject.budgetSettings
            New-CmAzCoreBillingRule -SettingsObject $budgetsObject

            Write-Verbose "Deploying Core Keyvault.."
            $SettingsObject.keyvaultSettings = Resolve-FilePath -NestedFile $SettingsObject.keyvaultSettings
            $keyVaultObject = Get-CmAzSettingsFile -Path $SettingsObject.keyvaultSettings
            New-CmAzCoreKeyVault -SettingsObject $keyVaultObject -TagSettingsFile $TagSettingsFile

            Write-Verbose "Deploying Core Automation Account.."
            $SettingsObject.automationSettings = Resolve-FilePath -NestedFile $SettingsObject.automationSettings
            $automationObject = Get-CmAzSettingsFile -Path $SettingsObject.automationSettings
            New-CmAzCoreAutomation -SettingsObject $automationObject -TagSettingsFile $TagSettingsFile
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}