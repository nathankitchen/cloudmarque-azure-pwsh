function Set-CmAzCoreTag {

	<#
		.Synopsis
		 Set tags on resources.

		.Description
		 Sets mandatory and custom tags on either specific resources or all the resources in a resource group.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Core

		.Example
		 Set-CmAzCoreTag -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 Set-CmAzCoreTag -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Set tags for resources")) {

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			Write-Verbose "Checking that the expected mandatory tags exist and are not empty..."
			$expectedMandatoryTagKeys = @("cm-owner", "cm-apps", "cm-charge", "cm-delete")

			$mandatoryTagsVariableName = "Tags.Mandatory"

			if (!$SettingsObject.Tags.Mandatory -or $expectedMandatoryTagKeys.Count -ne $SettingsObject.Tags.Mandatory.Keys.Count) {
				Write-Error "Incorrect number of mandatory tags set, please ensure that: $($expectedMandatoryTagKeys -join ',') exist." -Category InvalidArgument -CategoryTargetName $mandatoryTagsVariableName
			}

			$missingMandatoryKeys = $expectedMandatoryTagKeys | Where-Object { $SettingsObject.Tags.Mandatory.Keys -NotContains $_ }

			if ($missingMandatoryKeys) {

				$missingMandatoryKeysValue = [string]$missingMandatoryKeys

				Write-Error "$missingMandatoryKeysValue is missing from the mandatory tags section." -Category InvalidArgument -CategoryTargetName $mandatoryTagsVariableName
			}

			foreach ($actualMandatoryTagKey in $SettingsObject.Tags.Mandatory.Keys) {

				$tagValue = $SettingsObject.Tags.Mandatory[$actualMandatoryTagKey]

				if(!$tagValue) {
					Write-Error "Mandatory Tag - $actualMandatoryTagKey is null. Please set the appropriate Value in settings." -Category InvalidArgument -CategoryTargetName $mandatoryTagsVariableName
				}
				else {
					Write-Verbose "Tag - $actualMandatoryTagKey will be set as $tagValue..."
				}
			}

			Write-Verbose "Setting custom tags..."
			if ($SettingsObject.Tags.Custom) {

				foreach ($customTagKey in $SettingsObject.Tags.Custom.Keys) {

					$Value = $SettingsObject.Tags.Custom[$customTagKey]
					Write-verbose "Tag - $customTagKey will be set as $Value..."
				}
			}

			$allTags = $SettingsObject.Tags.Mandatory + $SettingsObject.Tags.Custom

			Write-Verbose "Fetching resources to be set..."
			$resourceIds = $SettingsObject.ResourceIds | Where-Object { $_ }

			if (!$resourceIds) {

				$resourceGroupName = $SettingsObject.ResourceGroupName

				if (!$resourceGroupName) {
					Write-Error "Provide resource id or resource group name." -Category InvalidArgument -CategoryTargetName $resourceGroupName
				}

				Write-Verbose "No specific resource ids provided. The command will run for the $resourceGroupName resource group..."

				$resourceGroup = @{}

				try {
					$resourceGroup = Get-AzResource -ResourceGroupName $resourceGroupName
				}
				catch {
					Write-Error "Issue locating resource group: $resourceGroupName." -Category ObjectNotFound -CategoryTargetName $resourceGroupName
				}

				$resourceIds = ($resourceGroup | Select-Object ResourceID).ResourceID

				Write-Verbose "Setting tags for $resourceGroupName..."
				Set-AzResourceGroup -Name $resourceGroupName -Tag @{ }
				Set-AzResourceGroup -Name $resourceGroupName -Tag $allTags
			}

			foreach ($resourceId in $resourceIds) {

				try {
					$resourceName = (Get-AzResource -ResourceID $resourceId).Name
				}
				catch {
					Write-Error "Issue locating resource: $resourceId." -Category ObjectNotFound -CategoryTargetName $resourceId -ErrorAction Continue
					continue
				}

				Write-Verbose "Setting tags for $resourceName : $resourceId..."
				Set-AzResource -ResourceID $resourceId -Tag @{ } -Force
				Set-AzResource -ResourceID $resourceId -Tag $allTags -Force -ErrorAction Continue
			}

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}