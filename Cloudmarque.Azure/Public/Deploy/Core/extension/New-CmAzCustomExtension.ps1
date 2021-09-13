function New-CmAzCustomExtension {

	<#
		.Synopsis
		 Enables generic deployment of an ARM template as a framework extension.

		.Description
		 Has following features:
			* Self-loading deployments using the component: "extension" header value.
			* A library of reusable templates automatically resolved in a [REPO]/extensions directory.
			* The ability to plug into useful functionality like the name generator and service locator.
			* Ability to use keyvault reference for secure strings.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Parameter TagSettingsFile
	     File path for the tag settings file to be converted into a tag settings object.

		.Parameter OmitTags
		 Parameter to specify if the cmdlet should handle its own tagging.

		.Component
		 IaaS

		.Example
		 New-CmAzCustomExtension -settingsFile "extensions.yml"

        .Example
		 New-CmAzCustomExtension -settingsObject $extensions
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings Yml File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Custom Extension")) {

			foreach ($name in $SettingsObject.names.keys) {

				$SettingsObject.names.$name.generatedName = Get-CmAzResourceName `
					-Resource $SettingsObject.names.$name.resource `
					-Architecture $SettingsObject.names.$name.architecture `
					-Location $SettingsObject.names.$name.location `
					-IncludeBuild $SettingsObject.names.$name.includeBuild `
					-Name $SettingsObject.names.$name.name
			}

			function Resolve-Dependency {

				param (
					[AllowEmptyString()]
					[String]$Location,
					[Boolean]$ThrowIfUnavailable,
					[Boolean]$ThrowIfMultiple,
					[string]$Service
				)

				if ($Location) {
					return Get-CmAzService `
						-Service $Service `
						-ThrowIfUnavailable:$ThrowIfUnavailable `
						-ThrowIfMultiple:$ThrowIfMultiple `
						-Location $Location
				}
				else {
					return Get-CmAzService `
						-Service $Service `
						-ThrowIfUnavailable:$ThrowIfUnavailable `
						-ThrowIfMultiple:$ThrowIfMultiple
				}
			}

			foreach ($template in $SettingsObject.templates) {

				$templateParameter = @{}

				foreach ($parameter in $template.parameters.keys) {

					$value = $template.parameters.$parameter.value
					$type = $template.parameters.$parameter.type

					switch ($type) {

						"static" {
							Write-Verbose "Static value: $value..."
							$templateParameter += @{ $parameter = $value }
						}

						"dependency" {

							Write-Verbose "Dependency value: $value..."

							$property = $template.parameters.$parameter.property

							$template.parameters.$parameter.throwIfUnavailable ??= $true
							$template.parameters.$parameter.throwIfMultiple ??= $true

							$resolvedDependency = Resolve-Dependency `
								-Service $value `
								-Location $template.parameters.$parameter.location `
								-ThrowIfMultiple $template.parameters.$parameter.throwIfMultiple `
								-ThrowIfUnavailable $template.parameters.$parameter.throwIfUnavailable

							if ($property) {
								$templateParameter += @{ $parameter = $resolvedDependency.$property }
							}
							else {
								$templateParameter += @{ $parameter = $resolvedDependency }
							}
						}

						"secureDependency" {

							$secretName = $template.parameters.$parameter.secretName

							if (!$secretName) {
								Write-Error "Please provide secret for parameter: $parameter" -Category InvalidArgument -TargetObject $parameter
							}

							Write-Verbose "SecureDependency value: $value..."

							$template.parameters.$parameter.throwIfUnavailable ??= $true
							$template.parameters.$parameter.throwIfMultiple ??= $true

							$resolvedDependency = Resolve-Dependency `
								-Service $value `
								-Location $template.parameters.$parameter.location `
								-ThrowIfMultiple $template.parameters.$parameter.throwIfMultiple `
								-ThrowIfUnavailable $template.parameters.$parameter.throwIfUnavailable

							$templateParameter += @{
								$parameter = @{
									reference = @{
										keyVault   = @{
											id = $resolvedDependency.id
										};
										secretName = $secretName
									}
								}
							}
						}

						"name" {
							Write-Verbose "Name value: $value..."

							if ($SettingsObject.names.$value.generatedName) {
								Write-Verbose "Found name: $value..."
								$templateParameter += @{ $parameter = $SettingsObject.names.$value.generatedName }
							}
							else {
								Write-Error "Invalid name: $value for $parameter..." -Category InvalidArgument -TargetObject $value
							}
						}
					}
				}

				if ([System.IO.Path]::IsPathRooted($templatePath)) {
					$templatePath = $template.name
				}
				else {
					$defaultPath = "$((Get-CmAzContext).projectRoot)/extensions/$($template.name)"

					if (Test-Path -Path $defaultPath) {
						Write-Verbose "Template Found in extensions..."
						$templatePath = $defaultPath
					}
					else {
						$templatePath = Resolve-FilePath -NestedFile $template.name

					}
				}

				if ($template.service.dependencies.resourceGroup) {

					$resourceGroup = Get-CmAzService -Service $template.service.dependencies.resourceGroup -ThrowIfUnavailable -ThrowIfMultiple -IsResourceGroup
					$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Core" -Location $resourceGroup.location -Name $MyInvocation.MyCommand.Name

					New-AzResourceGroupDeployment `
						-Name $deploymentName `
						-ResourceGroupName $resourceGroup.ResourceGroupName `
						-TemplateFile $templatePath `
						-TemplateParameterObject $templateParameter `
						-Force
				}
				else {

					if (!$template.location) {
						Write-Error "Location is mandatory for subscription scoped deployment..." -Category InvalidType -TargetObject $template.location
					}

					$deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Core" -Location $template.location -Name $MyInvocation.MyCommand.Name

					New-AzDeployment `
						-Name $deploymentName `
						-TemplateFile $templatePath `
						-TemplateParameterObject $templateParameter `
						-Location $template.location `
						-Force
				}
			}

			Write-CommandStatus -CommandName $MyInvocation.MyCommand.Name -Start $false
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}
