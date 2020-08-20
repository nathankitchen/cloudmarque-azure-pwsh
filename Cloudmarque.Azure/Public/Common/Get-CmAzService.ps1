function Get-CmAzService {

	<#
		.Synopsis
		 An implementation of the Service Locator pattern in PowerShell using Azure Tags to identify services.

		.Description
		 Finds Azure Resources based on the tag value of "cm-service", alongside additional filters for service type and
		 region. Service names can be anything, and can therefore be shaped to a specific organisation's context and uses.

		 The service locator pattern provides a canonical naming mechanism for Azure Resources which allows a component-based
		 deployments, where each component is responsible for locating its own dependencies. A deployment may then fail if its
		 dependencies are not deployed.

		.Component
		 Common

		.Parameter ServiceKey
		 Represents the service key to search for. By default, this is "cm-service", but it can be overridden. Do so with
		 caution, as this breaks a fundamental convention used in the Cloudmarque framework.

		.Parameter Service
		 Represents the service name to search for.

		.Parameter Region
		 A region to search within - allows the same service to be deployed in multiple regions, or other commands to
		 validate that the service is available in the specified region.

		.Parameter IsResourceGroup
		 Indicates whether the resource to be located is a resource group.

		.Parameter ThrowIfUnavailable
		 Indicates that an exception should be thrown if the specified resource is unavailable. This is useful in
		 scripts where dependencies are mandatory prior to provisioning. By default this is false, no service will
		 be returned but a "not found" message will be written in verbose mode.

		.Example
		 Find a keyvault
		 $keyVault = Get-CmAzService -Service "core-keys" -Region "USEast"

		.Example
		 Find a storage account for NSG logs
		 $storageAccount = Get-CmAzService -Service "core-monitoring-logs-nsg" -Region "USEast" -ResourceType "Microsoft.Storage"
	#>

	[CmdletBinding()]
	[OutputType([Hashtable])]
	param(
		[Parameter(Mandatory = $true)]
		[String]
		$Service,

		[String]
		$ServiceKey = "cm-service",

		[String]
		$Region,

		[Switch]
		$IsResourceGroup,

		[Switch]
		$ThrowIfUnavailable
	)

	Get-CmAzContext -RequireAzure -ThrowIfUnavailable | Out-Null

	$resource = @{}
	$tag = "$ServiceKey : $Service"

	if ($IsResourceGroup) {
		Write-Verbose "Searching for resource group with tag $($tag)"
		$resource = Get-AzResourceGroup -Tag @{ $ServiceKey = $Service }
	}
	else {
		Write-Verbose "Searching for resource with tag $($tag)"
		$resource = Get-AzResource -TagName $ServiceKey -TagValue $Service
	}

	if ($resource -is [system.array] -and $Region) {

		if ($Region) {
			$Region = $Region.Replace(" ", "")
			$resource = $resource | Where-Object { $_.Location -Eq $Region }
		}

		$resource = $resource | Select-Object -First 1
	}

	if ($resource) {

		@{
			name = $resource.name
			resourceId = $resource.resourceId
			resourceGroupName = $resource.resourceGroupName
			resourceType = $resource.resourceType
			location = $resource.location
			tags = $resource.tags
		}
	}
	elseif ($ThrowIfUnavailable) {
		Write-Error "Service not found. No resource with tag `"$($tag)`" could be found." -Category InvalidArgument -CategoryTargetName "ServiceKey : Service"
	}
	else {
		Write-Verbose "Service not found. No resource with tag `"$($tag)`" could be found."
	}
}