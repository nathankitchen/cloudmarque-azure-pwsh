
function New-CmAzCore {

    <#
		.Synopsis
		 Creates core solution.

		.Description
		 Completes the following:
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

        .Parameter AutomationCertificatePassword
         Certificate password used to create automation account run as certificate.

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
        [String]$TagSettingsFile,
        [Security.SecureString]$AutomationCertificatePassword
    )

    $ErrorActionPreference = "stop"

    try {

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Core Monitoring and Logging")) {

            if ($SettingsFile -and -not $SettingsObject) {
                $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
                $Directory = (Get-Item $SettingsFile).DirectoryName
            }
            elseif (-not $SettingsFile -and -not $SettingsObject) {
                Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
            }

            Write-Verbose "Setting publish values as global dependencies for further use.."
            $SettingsObject.service.dependencies = $SettingsObject.service.publish

            # Core Monitoring
            if (!$SettingsObject.actionGroups.name) {

                if (!$SettingsObject.monitorSettings) {
                    $SettingsObject.monitorSettings = "$Directory/monitor.yml"
                }

                $monitorObject = Get-CmAzSettingsFile -Path $SettingsObject.monitorSettings
                $monitorObject.Name = $SettingsObject.Name
                $monitorObject.location = $SettingsObject.location
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "activityLogAlert" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "appInsights" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "solution" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "storage" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "workspace" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "loggingResourceGroup" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "monitoringResourceGroup" -ResourceServiceContainer $monitorObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actionGroup" -ResourceServiceContainer $monitorObject
            }
            else {
                $monitorObject = $SettingsObject
            }

            Write-Verbose "Deploying core monitoring solution.."
            New-CmAzCoreMonitor -SettingsObject $monitorObject -TagSettingsFile $TagSettingsFile

            # Core Budgets
            if (!$SettingsObject.budgets.name) {

                if (!$SettingsObject.budgetSettings) {
                    $SettingsObject.budgetSettings = "$Directory/budgets.yml"
                }

                $budgetsObject = Get-CmAzSettingsFile -Path $SettingsObject.budgetSettings
                $budgetsObject.location = $SettingsObject.location
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actiongroup" -ResourceServiceContainer $budgetsObject -Isdependency
            }
            else {
                $monitorObject = $SettingsObject
            }

            Write-Verbose "Setting budgets.."
            New-CmAzCoreBillingRule -SettingsObject $budgetsObject

            # Core Key vault
            if (!$SettingsObject.resourceGroupName) {
                $SettingsObject.resourceGroupName = $SettingsObject.name
            }

            if (!$SettingsObject.keyVaults.name) {

                if (!$SettingsObject.keyvaultSettings) {
                    $SettingsObject.keyvaultSettings = "$Directory/keyvaults.yml"
                }
                $keyVaultObject = Get-CmAzSettingsFile -Path $SettingsObject.keyvaultSettings
                $keyVaultObject.resourceGroupName = $SettingsObject.resourceGroupName
                $keyVaultObject.location = $SettingsObject.location
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "workspace" -ResourceServiceContainer $keyVaultObject -Isdependency
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "actiongroup" -ResourceServiceContainer $keyVaultObject -Isdependency
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "resourceGroup" -ResourceServiceContainer $keyVaultObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "keyvault" -ResourceServiceContainer $keyVaultObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "activityLogAlert" -ResourceServiceContainer $keyVaultObject
            }
            else {
                $keyVaultObject = $SettingsObject
            }

            Write-Verbose "Deploying Core Keyvault.."
            New-CmAzCoreKeyVault -SettingsObject $keyVaultObject -TagSettingsFile $TagSettingsFile

            # Settings for Automation Account
            if (!$SettingsObject.automation.runbook.CertificateName -or !$SettingsObject.automation.runbook.keyVaultCertificatePasswordSecretName -or !$SettingsObject.automation.dsc.keyVaultCertificatePasswordSecretName -or !$SettingsObject.automation.dsc.CertificateName ) {

                if (!$SettingsObject.automationSettings) {
                    $SettingsObject.automationSettings = "$Directory/automation.yml"
                }

                $automationObject = Get-CmAzSettingsFile -Path $SettingsObject.automationSettings
                $automationObject.Name = $SettingsObject.resourceGroupName
                $automationObject.location = $SettingsObject.location
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "keyvault" -ResourceServiceContainer $automationObject -Isdependency
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "automation" -ResourceServiceContainer $automationObject
                Set-GlobalServiceValues -GlobalServiceContainer $SettingsObject -ServiceKey "resourceGroup" -ResourceServiceContainer $automationObject
            }
            else {
                $automationObject = $SettingsObject
            }

            Write-Verbose "Deploying Core Automation Account.."
            if ($AutomationCertificatePassword) {
                New-CmAzCoreAutomation -SettingsObject $automationObject -AutomationCertificatePassword $AutomationCertificatePassword -TagSettingsFile $TagSettingsFile
            }
            else {
                New-CmAzCoreAutomation -SettingsObject $automationObject -TagSettingsFile $TagSettingsFile
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}