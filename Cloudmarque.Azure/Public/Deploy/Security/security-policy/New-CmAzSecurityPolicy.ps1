function New-CmAzSecurityPolicy {
	<#
		.Synopsis
		 Creates Security Policies

		.Description
		 Completes following:
			* Creates policies.
			* Creates initiatives.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Component
		 Security

		.Example
		 New-CmAzSecurityPolicy -settingsFile "SecurityPolicy.yml"

		.Example
		 New-CmAzSecurityPolicy -settingsObject $SecurityPoliciesSettings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		$commandName = $MyInvocation.MyCommand.Name

		Write-CommandStatus -CommandName $commandName

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName $commandName

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create Security Policies")) {

			foreach ($initiative in $SettingsObject.initiatives) {

				Write-Verbose "Working on initiative: $($initiative.name) "
				$definitions += @()

				foreach ($definition in $initiative.definitions) {

					Write-Verbose "Adding definition: $definition "

					if ($initiative.definitionDirectory) {
						$policyFolder = Resolve-FilePath -NestedFile $initiative.definitionDirectory
					}
					else {
						$policyFolder = "$((Get-CmAzContext).projectRoot)/_policy"
					}

					$policy = "$policyFolder/$definition.json"
					$policyParameter = "$policyFolder/$definition.params.json"

					if (!(Test-Path -Path $policy)) {
						Write-Error "Policy file path is invalid for $definition." -Category InvalidArgument -CategoryTargetName "PolicyFile"
					}

					if (!(Test-Path -Path $policyParameter)) {
						Write-Error "Parameter file path is invalid for $definition." -Category InvalidArgument -CategoryTargetName "ParameterFile"
					}

					$policyDetails = Get-CmAzSettingsFile -Path $policy

					if (!$policyDetails.properties.displayName) {
						Write-Error "Display name missing from $definition." -Category InvalidArgument -CategoryTargetName "DisplayName"
					}

					if (!$policyDetails.properties.description) {
						Write-Error "Description is missing from $definition." -Category InvalidArgument -CategoryTargetName "Description"
					}

					$policyParameterDetails = Get-CmAzSettingsFile -Path $policyParameter -AsHashtable

					foreach ($key in $policyParameterDetails.keys) {

						$valueFromInitiative = ($initiative.parameters | Where-Object { $_.name -eq $key }).value

						if (!$policyParameterDetails.$key.defaultValue -and !$valueFromInitiative) {
							Write-Error "Missing value for parameter: $key" -Category InvalidArgument -CategoryTargetName "DefinitionParameter"
						}

						if ($valueFromInitiative){
							$defParamsInitiative += @{ $key = @{ value = $valueFromInitiative } }
						}
						else {
							Write-Verbose "Default value will be used for key: $key..."
						}
					}

					$newDefinition = New-AzPolicyDefinition -Name $policyDetails.properties.displayName -Description $policyDetails.properties.description -Policy $policy -Parameter $policyParameter

					if ($defParamsInitiative) {

						$definitions += @{
							policyDefinitionId = $newDefinition.PolicyDefinitionId
							parameters         = $defParamsInitiative
						}
					}
					else {

						$definitions += @{PolicyDefinitionId = $newDefinition.PolicyDefinitionId }
					}
				}

				if ($definitions.count -le 1) {

					$definitionJson = "[$($definitions | ConvertTo-Json -depth 100 -Compress)]"
				}
				else {
					$definitionJson = $definitions | ConvertTo-Json -depth 100 -Compress
				}

				$metaData = "{`"category`": `"$($initiative.category)`"}"

				New-AzPolicySetDefinition -Name $initiative.name -Metadata $metaData -PolicyDefinition $definitionJson -Description $initiative.description -verbose
			}

			Write-CommandStatus -CommandName $commandName -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}