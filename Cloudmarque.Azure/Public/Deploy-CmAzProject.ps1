function Deploy-CmAzProject {

    <#
		.Synopsis
		 Auto-deploys Azure resources depending on the type of component defined in settings.

        .Description
		 Wrapper function to auto-identify background script to process provided settings and deploy Azure infrastructure.

        .Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

        .Parameter SettingsObject
         Object containing the configuration values required to run this cmdlet.

        .Parameter TagSettingsFile
         File path for settings containing tags definition.

			* Uppercase
			* Lowercase
			* Numeric
			* Special

        .Component
		 Common

        .Example
         Deploy-CmAzProject -SettingsFile "c:/directory/settingsFile.yml"

        .Example
		 Deploy-CmAzProject -SettingsFile "c:/directory/settingsFile.yml" -TagSettingsFile "c:/directory/tags.yml"

        .Example
		 Deploy-CmAzProject -SettingsFile "c:/directory/virtualmachine.yml" -LocalAdminUsername $adminUser -LocalAdminPassword $adminPassword
	#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]

    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject,
        [String]$TagSettingsFile
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
