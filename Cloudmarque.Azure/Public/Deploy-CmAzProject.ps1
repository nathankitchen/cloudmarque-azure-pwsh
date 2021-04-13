function Deploy-CmAzProject {

    <#
		.Synopsis
		 Auto deploys resources specified in targeted directories and files of various types.

        .Description
		 Auto deploys resources with the following file types:
         * Powershell (.ps1)
         * Arm Templates (.json)
         * Azure Bicep file (.bicep)
         * Cloudmarque Yml files via New-CmAzDeployment
         * Directories containing any of the above.

        .Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

        .Parameter SettingsObject
         Object containing the configuration values required to run this cmdlet.

        .Component
		 Common

        .Example
         Deploy-CmAzProject -SettingsFile "c:/directory/settingsFile.yml"
	#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]

    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject
    )

    $ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Project")) {

        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem);
    }
}
