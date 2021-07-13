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
         File path for the settings containing tags definition.

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

        Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

        $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Core Monitoring and Logging")) {

            $SettingsFiles = @(
                "monitorSettings",
                "budgetSettings",
                "keyvaultSettings",
                "automationSettings"
            )

            foreach ($SettingsFile in $SettingsFiles) {

                Write-Verbose "$SettingsFile found.. "

                $SettingsObject.$SettingsFile = Resolve-FilePath -NestedFile $SettingsObject.$SettingsFile

                if(!$SettingsObject.$SettingsFile.contains('.yml')){
                    $SettingsObject.$SettingsFile = "$($SettingsObject.$SettingsFile).yml"
                }

                $SettingsObject.($SettingsFile.Replace('Settings', 'Object')) = Get-CmAzSettingsFile -Path $SettingsObject.$SettingsFile
            }

            Write-Verbose "Deploying core monitoring solution.."
            New-CmAzCoreMonitor -SettingsObject $SettingsObject.MonitorObject -TagSettingsFile $TagSettingsFile

            Write-Verbose "Setting budgets.."
            New-CmAzCoreBillingRule -SettingsObject $SettingsObject.budgetObject

            Write-Verbose "Deploying Core Keyvault.."
            New-CmAzCoreKeyVault -SettingsObject $SettingsObject.keyVaultObject -TagSettingsFile $TagSettingsFile

            Write-Verbose "Deploying Core Automation Account.."
            New-CmAzCoreAutomation -SettingsObject $SettingsObject.automationObject -TagSettingsFile $TagSettingsFile
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}