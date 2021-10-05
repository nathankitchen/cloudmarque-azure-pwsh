function New-CmAzService {

    <#
        .Synopsis
         Sets up external resources as services to be leveraged by Cloudmarque.

        .Description
         Tag specific resources or resource group with the "cm-service" tag and a specified value.
         This cmdlet is intended for use with resources not natively deployed with Cloudmarque.

        .Parameter SettingsFile
         File path for the settings file to be converted into a settings object.

        .Parameter SettingsObject
         Object containing the configuration values required to run this cmdlet.

        .Component
         Common

        .Example
         New-CmAzService -SettingsFile "c:/directory/settingsFile.yml"

        .Example
         New-CmAzService -SettingsObject $settings
	#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject
    )

    $ErrorActionPreference = "stop"

    try {

        Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

        $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Service Locator Tag/s")) {

            $SettingsObject.services | ForEach-Object -Parallel {

                $service = $_
                $serviceTag = @{ "cm-service" = $service.value }

                ($service.resourceGroupIds + $service.resourceIds) | ForEach-Object {

                    $resourceId = $_

                    Update-AzTag -ResourceId $resourceId -Tag $serviceTag -Operation Merge
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}