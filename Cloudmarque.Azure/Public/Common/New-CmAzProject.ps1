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
		 

		.Example
		 New-CmAzProject -Project "MyProject"
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Project
	)

	if ($PSCmdlet.ShouldProcess($Project, "Create new directory")) {

		Write-Output $((Get-PsCallStack)[0])

		$Source = "$PSScriptRoot/../../Resources/Project"
		$Files = "*"

		New-Item -Path $Project -ItemType Directory -Force | Out-Null

		Get-ChildItem $Source | Copy-Item -Destination $Project -Recurse -filter $Files
	}
}