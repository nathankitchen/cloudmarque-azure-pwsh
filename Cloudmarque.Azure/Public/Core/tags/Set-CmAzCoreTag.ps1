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

	function MergeHashTables() {

		param(
			[parameter(Mandatory = $true)]
			[hashtable]$hashtableToFilter,
			[parameter(Mandatory = $true)]
			[hashtable]$hashtableToAdd
		)

		$hashtableToFilter.GetEnumerator() | ForEach-Object {
			if ($_.key -and $hashtableToAdd.keys -notcontains $_.key) {
				$hashtableToAdd.Add($_.key, $_.value)
			}
		}

		return $hashtableToAdd
	}

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Set tags for resources")) {

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			Write-Verbose "Checking that the expected mandatory tags exist and are not empty..."
			$expectedMandatoryTagKeys = @("cm-owner", "cm-apps", "cm-charge")

			$mandatoryTagsVariableName = "Tags.Mandatory"

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

			$resources = @()

			Write-Verbose "Fetching resources to be set..."
			if ($SettingsObject.ResourceIds) {

				foreach ($resourceId in $SettingsObject.ResourceIds) {

					try {
						Write-Verbose "Fetching $resourceId..."
						$resources += Get-AzResource -ResourceID $resourceId
					}
					catch {
						Write-Error "Issue locating resource: $resourceId." -Category ObjectNotFound -CategoryTargetName $resourceId
					}
				}
			}
			elseif ($SettingsObject.ResourceGroupName) {

				$resourceGroup = $null

				try {
					Write-Verbose "Fetching resource group $($SettingsObject.ResourceGroupName)..."
					$resourceGroup = Get-AzResourceGroup -ResourceGroupName $SettingsObject.ResourceGroupName
				}
				catch {
					Write-Error "Issue locating resource group: $($SettingsObject.ResourceGroupName)." -Category ObjectNotFound -CategoryTargetName $SettingsObject.ResourceGroupName
				}

				$tagsToSet = @{}
				$tagsToSet += $allTags

				if($resourceGroup.tags) {
					$tagsToSet = MergeHashTables -hashtableToFilter $resourceGroup.tags -hashtableToAdd $tagsToSet
				}

				Write-Verbose "Setting tags for $($SettingsObject.ResourceGroupName)..."
				Set-AzResourceGroup -Name $SettingsObject.ResourceGroupName -Tag $tagsToSet

				try {
					Write-Verbose "Fetching resources in $($SettingsObject.ResourceGroupName)..."
					$resources = Get-AzResource -ResourceGroupName $SettingsObject.ResourceGroupName
				}
				catch {
					Write-Error "Issue locating resources in resource group: $($SettingsObject.ResourceGroupName)." -Category ObjectNotFound -CategoryTargetName $ResourceGroupName
				}
			}
			else {
				Write-Error "Provide resource id or resource group name." -Category InvalidArgument -CategoryTargetName $SettingsObject.ResourceGroupName
			}

			foreach($resource in $resources) {

				$tagsToSet = @{}
				$tagsToSet += $allTags

				if($resource.tags) {
					$tagsToSet = MergeHashTables -hashtableToFilter $resource.tags -hashtableToAdd $tagsToSet
				}

				Write-Verbose "Setting tags for $($resource.name)..."
				if ($resource.ResourceType -eq 'Microsoft.Network/frontdoors') {
					# Work around as Azure FrontDoor does not support setting tags via PATCH operations
					Set-AzFrontDoor -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -Tag $tagsToSet
				}
				else {
					Set-AzResource -ResourceID $resource.Id -Tag $tagsToSet -Force
				}
			}

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}