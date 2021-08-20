function Get-CmAzSettingsFile {

	<#
		.Synopsis
		 Gets a file containing settings used by Cloudmarque and returns an object representation.

		.Description
		 Parses either a JSON or YAML file and returns the resulting data object. This allows
		 callers to use whichever serialization format they prefer when defining and managing
		 Cloudmarque settings.

		.Component
		 Common

		.Parameter Path
		 The file path of the settings file to parse.
		 
		.Parameter AsHashtable
		 Parses JSON as hashtable.

		.Example
		 Get-CmAzSettingsFile -Path settings.yml
    #>

	[CmdletBinding()]
	[OutputType([PSObject])]
	param(
		[Parameter(Mandatory = $true)]
		[String]
		$Path,
		[Switch]
		$AsHashtable
	)

	$ResolvedPath = Resolve-FilePath -NestedFile $Path

	if (!(Test-Path -Path $ResolvedPath -IsValid) -or !(Test-Path -Path $ResolvedPath)) {
		throw "Invalid Path. `nNot able to access '$ResolvedPath'. Please provide a path that is valid and exists."
	}

	$file = Get-Item -Path $ResolvedPath
	$content = Get-Content -Path $ResolvedPath -Raw
	$dataObject = $Null

	switch -Regex ($file.Extension) {
		"yaml|yml" {
			$dataObject = ConvertFrom-YAML $content
		}
		"json|js" {
			$dataObject = ConvertFrom-Json $content -AsHashtable:$AsHashtable
		}
	}

	# Put the resulting object into the pipe
	$dataObject
}
