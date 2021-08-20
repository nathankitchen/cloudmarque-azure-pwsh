#
# Module manifest for module 'Cloudmarque.Azure'
#
# Generated by: Nathan Kitchen
#
# Generated on: 9/10/2020
#

@{
# Script module or binary module file associated with this manifest.
RootModule = 'Cloudmarque.Azure.psm1'

# Version number of this module.
ModuleVersion = '1.0.14.1'

# Supported PSEditions
CompatiblePSEditions = 'Core'

# ID used to uniquely identify this module
GUID = '76dd2ffa-8826-4862-8adc-8c6fd89e2d9d'

# Author of this module
Author = 'Nathan Kitchen'

# Company or vendor of this module
CompanyName = 'Trustmarque'

# Copyright statement for this module
Copyright = '(c) 2020 Trustmarque. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Cloudmarque PowerShell Tools for Azure is a deployment and management framework for cloud resources following a DevOps/GitOps methodology aligned with the Cloudmarque Reference Architecture and Operating Model.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
    @{ ModuleName = 'Az.Accounts'; ModuleVersion = '1.9.3'; },
    @{ ModuleName = 'Az.Advisor'; RequiredVersion = '1.1.1'; },
    @{ ModuleName = 'Az.ApiManagement'; RequiredVersion = '2.1.0'; },
    @{ ModuleName = 'Az.ApplicationInsights'; RequiredVersion = '1.1.0'; },
    @{ ModuleName = 'Az.Automation'; RequiredVersion = '1.4.0'; },
    @{ ModuleName = 'Az.Cdn'; RequiredVersion = '1.4.3'; },
    @{ ModuleName = 'Az.Compute'; RequiredVersion = '4.3.1'; },
    @{ ModuleName = 'Az.DesktopVirtualization'; RequiredVersion = '2.0.0'; },
    @{ ModuleName = 'Az.FrontDoor'; RequiredVersion = '1.6.1'; },
    @{ ModuleName = 'Az.Keyvault'; RequiredVersion = '2.1.0'; },
    @{ ModuleName = 'Az.Network'; RequiredVersion = '3.3.0'; },
    @{ ModuleName = 'Az.OperationalInsights'; RequiredVersion = '2.3.0'; },
    @{ ModuleName = 'Az.Resources'; RequiredVersion = '2.5.0'; },
    @{ ModuleName = 'Az.Storage'; RequiredVersion = '2.5.0'; },
    @{ ModuleName = 'Az.Security'; RequiredVersion = '0.8.0'; },
    @{ ModuleName = 'Az.Websites'; RequiredVersion = '1.11.0'; },
    @{ ModuleName = 'GetPassword'; RequiredVersion = '1.0.0.0'; }
    @{ ModuleName = 'Powershell-Yaml'; RequiredVersion = '0.4.2'; })

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Clear-CmAzContext', 'Get-CmAzContext', 'Get-CmAzResourceName',
                'Get-CmAzService', 'Get-CmAzSettingsFile', 'Get-CmAzSubscriptionName',
                'New-CmAzProject', 'Set-CmAzContext', 'Test-CmAzPackage',
                'New-CmAzCore', 'New-CmAzCoreAutomation',
                'Set-CmAzCoreAutomationDeleteResource', 'New-CmAzCoreBillingRule',
                'New-CmAzCoreKeyVault', 'New-CmAzCoreMonitor',
                'New-CmAzRecoveryServicesVault', 'Set-CmAzTag',
                'New-CmAzIaasBastionHost', 'New-CmAzIaasNetworking', 'New-CmAzIaasVm',
                'Set-CmAzIaasUpdateManagement', 'New-CmAzIaasVpnGw', 'New-CmAzIaasFirewalls',
                'New-CmAzIaasWvd', 'New-CmAzPaasSql', 'New-CmAzPaasWeb', 'New-CmAzPaasFunction', 'New-CmAzDeployment',
                'New-CmAzPaasWebStatic', 'Set-BlobStorageContentType', 'New-CmAzMonitorLogAlerts', 'New-CmAzMonitorMetricAlerts',
                'New-CmAzSecurityPartner', 'Set-CmAzSecurityCentre', 'New-CmAzIaasStorage', 'New-CmAzIaasVnetPeerings',
                'New-CmAzIaasPrivateEndpoints', 'New-CmAzCustomExtension', 'New-CmAzSecurityPolicy'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
# VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Cloudmarque','Cloud','Azure','Devops','Gitops'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/Trustmarque/cloudmarque-azure-pwsh/blob/master/LICENSE.md'

        # A URL to the main website for this project.
        ProjectUri = 'https://docs.trustmarque.com/cloudmarque'

        # A URL to an icon representing this module.
        IconUri = 'https://github.com/Trustmarque/cloudmarque-azure-pwsh/blob/master/Cloudmarque.Azure/icon.png?raw=true'

        # ReleaseNotes of this module
        ReleaseNotes = '* Hotfix for the New-CmAzPaasWebStatic cmdlet, that was not passing in the correct resource group service dependency value into New-CmAzIaasStorage.'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

    } # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://docs.trustmarque.com/cloudmarque/'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''
}
