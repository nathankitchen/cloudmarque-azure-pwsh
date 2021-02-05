function Set-CmAzTag {

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
		 Common

		.Example
		 Set-CmAzTag -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 Set-CmAzTag -SettingsObject $settings
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

        Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		$SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Set tags for resources")) {

			$cmazContext = Get-CmAzContext

			$sourceTypeInfo = $cmazcontext.builddefinitionname.trim(")").split("(")

			$SettingsObject.Tags.Mandatory["cm-source"] = "$($sourceTypeInfo[0]) $($cmazContext.date)"
			$SettingsObject.Tags.Mandatory["cm-type"] = $sourceTypeInfo[1]

			$allTags = $SettingsObject.Tags.Mandatory

			Write-Verbose "Setting custom tags..."
			if ($SettingsObject.Tags.Custom) {
				$allTags += $SettingsObject.Tags.Custom
			}

			$SettingsObject.ResourceIds = $SettingsObject.ResourceIds | Where-Object { $_ }
			$SettingsObject.ResourceGroupIds = $SettingsObject.ResourceGroupIds | Where-Object { $_ }

			$resources = @()

			Write-Verbose "Fetching resources to be set..."
			if ($SettingsObject.ResourceIds) {

				foreach ($resourceId in $SettingsObject.ResourceIds) {

					Write-Verbose "Fetching $resourceId..."
					if ($resourceId.startsWith("/subscriptions/") -Or $resourceId -Contains "/") {
						$existingResources = Get-AzResource -ResourceID $resourceId -ErrorAction Continue
					}
					else {
						$existingResources = Get-AzResource -Name $resourceId -ErrorAction Continue
					}

					if (!$existingResources) {
						Write-Error "Issue locating resource: $resourceId." -Category ObjectNotFound -CategoryTargetName $resourceId
					}

					$resources += $existingResources
				}
			}
			elseif ($SettingsObject.ResourceGroupIds) {

				foreach ($resourceGroupId in $SettingsObject.ResourceGroupIds) {

					$resourceGroup = $null

					try {
						Write-Verbose "Fetching resource group $($resourceGroupId)..."
						$resourceGroup = Get-AzResourceGroup -ResourceGroupName $resourceGroupId
					}
					catch {
						Write-Error "Issue locating resource group: $($resourceGroupId)." -Category ObjectNotFound -CategoryTargetName "ResourceGroupIds"
					}

					$tagsToSet = @{}
					$tagsToSet += $allTags

					if ($resourceGroup.tags) {
						$tagsToSet = Merge-HashTables -HashtableToFilter $resourceGroup.tags -HashtableToAdd $tagsToSet
					}

					Write-Verbose "Setting tags for $($resourceGroupId)..."
					Set-AzResourceGroup -Name $resourceGroupId -Tag $tagsToSet

					try {
						Write-Verbose "Fetching resources in $($resourceGroupId)..."
						$resources += Get-AzResource -ResourceGroupName $resourceGroupId
					}
					catch {
						Write-Error "Issue locating resources in resource group: $($resourceGroupId)." -Category ObjectNotFound -CategoryTargetName "ResourceGroupIds"
					}

				}
			}
			else {
				Write-Error "Provide resource id or resource group name." -Category InvalidArgument -CategoryTargetName "ResourceGroupIds"
			}

			Write-Verbose "Tagging initiated.."

			$resources  | ForEach-Object -Parallel {

				$tagsToSet = @{}
				$tagsToSet += $using:allTags

				$resource = $_

				if ($resource.tags) {

					. "$using:PSScriptRoot/../../Private/Utility/Merge-Hashtables.ps1"
					$tagsToSet = Merge-HashTables -HashtableToFilter $resource.tags -HashtableToAdd $tagsToSet
				}

				Write-Verbose "Setting tags for $($resource.name)..."
				if ($resource.ResourceType -eq 'Microsoft.Network/Frontdoors') {

					# Work around as Azure FrontDoor does not support setting tags via PATCH operations
					Set-AzFrontDoor -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -Tag $tagsToSet > $null
				}
				else {
					Set-AzResource -ResourceID $resource.Id -Tag $tagsToSet -Force > $null
				}
			}

			Write-Verbose "Finished tagging resources!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem);
	}
}