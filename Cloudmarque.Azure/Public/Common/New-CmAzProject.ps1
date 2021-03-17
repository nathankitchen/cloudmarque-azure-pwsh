function New-CmAzProject {

	<#
		.Synopsis
		 Creates a template Cloudmarque project with default settings.

		.Description
		 Creates a new directory containing a sample environment for deployment.

		.Component
		 Common

		.Parameter Project
		 The filepath where the user's Cloudmarque project will be set.

		.Parameter ConfigName
		 The name of the project configuration to load.
		
		.Parameter ListAvailable
		 Confirm weither to list the available project configurations instead.

		.Example
		 New-CmAzProject -Project "MyProject" -Name "Integration"
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
	param(
		[string]$Project,
		[string]$ConfigName = "Integration",
		[switch]$ListAvailable
	)

	$ErrorActionPreference = "Stop"

	if ($PSCmdlet.ShouldProcess($Project, "Create new directory")) {

		$source = "$PSScriptRoot\..\..\Resources\Project"

		$availableConfigs = Get-ChildItem -Path $source -Directory -Force

		if($ListAvailable) {
			$availableConfigs.baseName
		}
		elseif (!$Project) {
			Write-Error "Please specify a output directory" -Category InvalidArgument -CategoryTargetName "ConfigName"
		}
		elseif ($availableConfigs.baseName -NotContains $ConfigName) {
			Write-Error "Project configuration not found." -Category InvalidArgument -CategoryTargetName "Project"
		}
		else {

			New-Item -Path $Project -ItemType Directory -Force > $Null
	
			Get-ChildItem "$source/$ConfigName" | Copy-Item -Destination $Project -Recurse -Filter "*" -Force
	
			Write-Verbose "Initialized new Project Directory."
		}
	}
}