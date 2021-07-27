function New-CmAzDeployment {

    <#
		.Synopsis
		 Auto-deploys Azure resources depending on the type of component defined in settings.

        .Description
		 Wrapper function to auto-identify background script to process provided settings and deploy Azure infrastructure.

        .Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

        .Parameter SettingsObject
         Object containing the configuration values required to run this cmdlet.

        .Parameter PolicySettingsFile
		 Policy file path for the settings file to be converted into a settings object New-CmAzIaasRecoveryServicesVault.

        .Parameter PolicySettingsObject
         Policy object containing the configuration values required to run this New-CmAzIaasRecoveryServicesVault.

        .Parameter TagSettingsFile
         File path for settings containing tags definition.

        .Parameter LocalAdminUsername
		 Local admin username for deployed vms, max length 20 characters.

        .Parameter LocalAdminPassword
		 Local admin passwords for deployed vms, requires three of the following character types:
			* Uppercase
			* Lowercase
			* Numeric
			* Special

        .Component
		 Common

        .Example
         New-CmAzDeployment -SettingsFile "c:/directory/settingsFile.yml"

        .Example
		 New-CmAzDeployment -SettingsFile "c:/directory/settingsFile.yml" -TagSettingsFile "c:/directory/tags.yml"

        .Example
		 New-CmAzDeployment -SettingsFile "c:/directory/virtualmachine.yml" -LocalAdminUsername $adminUser -LocalAdminPassword $adminPassword
	#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        [String]$PolicySettingsFile,
        [Object]$PolicySettingsObject,
        [String]$TagSettingsFile,
        [parameter(Mandatory = $false)]
        [SecureString]$LocalAdminUsername,
        [parameter(Mandatory = $false)]
        [SecureString]$LocalAdminPassword
    )

    $ErrorActionPreference = "Stop"

    try {

        if ($SettingsFile -and !$SettingsObject) {
            $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
        }
        elseif (!$SettingsFile -and !$SettingsObject) {
            Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
        }

        switch ($SettingsObject.component) {

            core {
                New-CmAzCore -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            automation {
                New-CmAzCoreAutomation -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            logAlerts {
                New-CmAzMonitorLogAlerts -SettingsObject $SettingsObject
            }

            metricAlerts {
                New-CmAzMonitorMetricAlerts -SettingsObject $SettingsObject
            }

            deleteservice {
                Set-CmAzCoreAutomationDeleteResource -SettingsObject $SettingsObject
            }

            budgets {
                New-CmAzCoreBillingRule -SettingsObject $SettingsObject
            }

            keyvaults {
                New-CmAzCoreKeyVault -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            monitor {
                New-CmAzCoreMonitor -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            bastionhosts {
                New-CmAzIaasBastionHost -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            networking {
                New-CmAzIaasNetworking -SettingsFile $SettingsFile -TagSettingsFile $TagSettingsFile
            }

            privateEndpoints {
                New-CmAzIaasPrivateEndpoints -SettingsFile $SettingsFile -TagSettingsFile $TagSettingsFile
            }

            vnetPeerings {
                New-CmAzIaasVnetPeerings -SettingsObject $SettingsObject
            }

            firewalls {
                New-CmAzIaasFirewalls -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            recoveryvault {

                if ($PolicySettingsFile -and !$PolicySettingsObject) {
                    $PolicySettingsObject = Get-CmAzSettingsFile -Path $PolicySettingsFile
                }
                elseif (!$PolicySettingsFile -and !$PolicySettingsObject) {
                    Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "PolicySettingsObject"
                }

                New-CmAzIaasRecoveryServicesVault -SettingsObject $SettingsObject -PolicySettingsObject $PolicySettingsObject -TagSettingsFile $TagSettingsFile
            }

            services {
                New-CmAzService -SettingsObject $SettingsObject
            }

            storage {
                New-CmAzIaasStorage -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            tags {
                Set-CmAzTag -SettingsObject $SettingsObject
            }

            virtualmachines {
                New-CmAzIaasVm -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile -LocalAdminUsername $LocalAdminUsername -LocalAdminPassword $LocalAdminPassword
            }

            vpngw {
                New-CmAzIaasVpnGw -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            wvd {
                New-CmAzIaasWvd -SettingsObject $SettingsObject
            }

            sharedImageGallery {
                New-CmAzPaasSharedImageGallery -SettingsObject $SettingsObject
            }

            sql {
                New-CmAzPaasSql -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            web {
                New-CmAzPaasWeb -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            functions {
                New-CmAzPaasFunction -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            webStatic {
                New-CmAzPaaSWebStatic -SettingsObject $SettingsObject -TagSettingsFile $TagSettingsFile
            }

            securityCentre {
                Set-CmAzSecurityCentre -SettingsObject $SettingsObject
            }

            updateManagement {
                Set-CmAzIaasUpdateManagement -SettingsObject $SettingsObject
            }

            Default {
                Write-Error "Please provide appropriate component value in settings file or object.."
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}
