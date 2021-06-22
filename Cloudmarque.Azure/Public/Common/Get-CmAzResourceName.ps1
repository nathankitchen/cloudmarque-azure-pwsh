﻿function Get-CmAzResourceName {

	<#
		.Synopsis
		 Generates a name for a resource based on predefined naming conventions.

		.Description
		 Returns a message, validating that the package has been correctly installed.

		.Component
		 Common

		.Parameter Resource
		 The type of the resource.

		.Parameter Architecture
		 Infrastructure the resource is used for.

		.Parameter Location
		 Where the resource will be located.

		.Parameter Name
		 Custom value to provide contextual value to the resource.

		.Parameter SubscriptionName
		 Name of the subscription the resource will be deployed in, defaults to the current subscription in the azcontext.

		.Parameter IncludeBuild
		 For VM and VMscalesets replaces hash with build ID. For all other resources appends build id to hash.

		.Parameter MaxLength
		 Max length of the name to be generated.

		.Example
		 Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Location "UK South" -Name "DocsWebsite"
		 Output: rg-docswebsite-core-97547bfe

		.Example
		 Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "Core" -Location "UK South" -Name "NewWebsite" -IncludeBuild
		 Output: rg-newwebsite-core-2a04bdf4-001

		.Example
		 Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "Core" -Location "UK South" -Name "mywindows" -IncludeBuild
		 Output: vmmywindows001

		.Example
		 Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "Core" -Location "UK South" -Name "mywindows"
		 Output: vmmywindowsa941
	#>

	[CmdletBinding()]
	[OutputType([PSObject])]
	param(
		[Parameter(Mandatory = $true)]
		[String]
		$Resource,

		[Parameter(Mandatory = $true)]
		[String]
		$Architecture,

		[Parameter(Mandatory = $true)]
		[String]
		$Location,

		[Parameter(Mandatory = $true)]
		[String]
		$Name,

		[String]
		$SubscriptionName = (Get-AzContext).SubscriptionName,

		[switch]
		$IncludeBuild = $False,

		[Int]
		$MaxLength = 0
	)
	process {
		try {
			$ctx = Get-CmAzContext -ThrowIfUnavailable

			$generators = Get-CmAzSettingsFile -Path "$($ctx.ProjectRoot)\_names\generators.yml";
			$tokens = Get-CmAzSettingsFile -Path "$($ctx.ProjectRoot)\_names\tokens.yml";
			$locations = Get-CmAzSettingsFile -Path "$($ctx.ProjectRoot)\_names\locations.yml";
			$resources = Get-CmAzSettingsFile -Path "$($ctx.ProjectRoot)\_names\resources.yml";
			$buildId = (Get-CmAzContext).BuildId

			$generatedName = "";
			$nameSegments = @();

			$locationConvention = $locations.locations | Where-Object { $_.name -Eq $Location -or $_.alias -Eq $Location }

			if (!$locationConvention) {
				throw "No location naming convention found in _names\locations.yml for '$Location'"
			}

			$resourceConvention = $resources.resources | Where-Object { $_.name -Eq $Resource }

			$resourceShortname = $resources.defaults.shortname;
			$generator = $resources.defaults.generator;

			# We found a resource-based convention, which probably has its own generator.
			if ($resourceConvention) {

				$generator = $resourceConvention.generator;
				$resourceShortname = $resourceConvention.shortname;

				if (!$MaxLength) {
					$MaxLength = $resourceConvention.maxLength;
				}

				Write-Verbose "Found resource-based convention for $Resource ($resourceShortname), selecting generator $generator";
			}
			else {
				Write-Verbose "No resource-based convention for $Resource ($resourceShortname), defaulting to generator $generator";
			}

			$gen = $generators.formats | Where-Object { $_.name -Eq $generator }

			if (!$gen) {
				throw "_naming/resources.yml refers to a generator $generator which does not exist in _naming/generators.yml"
			}

			foreach ($component in $gen.components) {
				switch ($component.source) {
					"organisation" { $nameSegments += $tokens.organisation }
					"project" { $nameSegments += $tokens.project }
					"architecture" { $nameSegments += $tokens.architecture[$Architecture.ToLower()] }
					"environment" { $nameSegments += $tokens.environments[$ctx.Environment.ToLower()] }
					"resource" { $nameSegments += $resourceShortname }
					"location" { $nameSegments += $locationConvention.shortname }
					"name" { $nameSegments += $Name.ToLower() }
					"subscriptionName" { $nameSegments += $SubscriptionName[0..3] }
					"packageVersion" { $nameSegments += $ctx.packageVersion }

					"buildId" {

						if ($IncludeBuild) {
							$nameSegments += $buildId
						}
						else {
							$hash = $nameSegments -Join $gen.separator
							$hash += "|" + $settings.tokens.salt

							$bytes = [System.Text.Encoding]::UTF8.GetBytes($hash)
							$algorithm = [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
							$sb = New-Object System.Text.StringBuilder

							$algorithm.ComputeHash($bytes) |
							ForEach-Object {
								$null = $sb.Append($_.ToString("x2"))
							}
							$hashLength = if ($component.maxLength) { $component.maxLength } else { 8 }
							$nameSegments += $sb.ToString().Substring(0, $hashLength)
						}
					}

					"hash" {

						$hash = $nameSegments -Join $gen.separator
						$hash += "|" + $settings.tokens.salt

						$bytes = [System.Text.Encoding]::UTF8.GetBytes($hash)
						$algorithm = [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
						$sb = New-Object System.Text.StringBuilder

						$algorithm.ComputeHash($bytes) |
						ForEach-Object {
							$null = $sb.Append($_.ToString("x2"))
						}
						$hashLength = if ($component.maxLength) { $component.maxLength } else { 8 }
						$nameSegments += $sb.ToString().Substring(0, $hashLength)

						if ($IncludeBuild) {
							$nameSegments += $buildId
						}
					}

					"timestamp" {

						$timestamp = Get-Date -Format "s"
						$nameSegments += $timestamp
					}
				}
			}

			# Strip out any empty entries so that we don't end up with double dashes
			# anywhere within a name.
			$nameSegments = $nameSegments | Where-Object { $_ }

			$generatedName = $nameSegments -Join $gen.separator

			if ($gen.removeCharacters) {

				foreach ($charToRemove in $gen.removeCharacters) {
					$generatedName = $generatedName.replace($charToRemove, '')
				}
			}

			if ($MaxLength -Gt 0) {

				$length = if ($generatedName.Length -Gt $MaxLength) { $MaxLength } else { $generatedName.Length }
				$generatedName = $generatedName.Substring(0, $length)
			}

			$generatedName = $generatedName.trimEnd("-")

			$generatedName
		}
		catch {
			$PSCmdlet.ThrowTerminatingError($PSitem)
		}
	}
}