function New-CmAzIaasNetworking {

	<#
		.Synopsis
		 Creates networking solution

		.Description
		 Completes following:
			* Creates vnets and subnets. Optionally attach nsg and route tables to subnet.
			* Creates route tables and routes.
			* Creates network security groups.
			* Creates resource groups if doesn't exist.
			* Configure resources in mulitple resource groups at once.
			* Ability to optionally configure networking component independently.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter VnetsCsvFile
		 File path for the csv containing virtual network configurations.
		 Required headers: resourceGroupName|location(optional)|vnetName|addressSpace|subnetName|cidr|networkSecurityGroup|routeTable.

		.Parameter RouteTablesCsvFile
		 File path for the csv containing route table configurations.
		 Required headers: resourceGroupName|location(optional)|tableName|routeName|cidr|nextHopType|nextHopIpAddress|notes

		.Parameter NsgsCsvFile
		 File path for the csv containing virtual network security group configurations.
		 Required headers: resourceGroupName|location(optional)|nsgName|ruleName|priority|direction|sourceIp|sourcePort|destinationIp|destinationPort|protocol|Access|Description

		.Parameter ResourceGroupsCsvFile
		 File path for the csv containing resource Group and location mapping. By default location of first vnet is used to create resource group.
		 Required headers: resourceGroupName|location

		.Parameter TagSettingsFile
     	 File path for settings containing tags definition.

		.Component
		 IaaS

		.Example
		 New-CmAzIaasNetworking -settingsFile "networking.yml"

		.Example
		 New-CmAzIaasNetworking -VnetsCsvFile "vnet.csv" -RouteTablesCsvFile "routeTable.csv" -NsgsCsvFile "nsg.csv" -ResourceGroupCsvFile resourceGroup.csv -Confirm:$false

		.Example
		 New-CmAzIaasNetworking -VnetsCsvFile "vnet.csv" -RouteTablesCsvFile "routeTable.csv" -NsgsCsvFile "nsg.csv" -Confirm:$false

		.Example
		 New-CmAzIaasNetworking -RouteTablesCsvFile "routeTable.csv" -Confirm:$false

	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings Yml File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$VnetsCsvFile,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$RouteTablesCsvFile,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$NsgsCsvFile,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$ResourceGroupsCsvFile,
		[String]$TagSettingsFile
	)

	$ErrorActionPreference = "Stop"

	try {

		Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create networking solution")) {

			if ($SettingsFile -and !$SettingsObject -and !$VnetsCsvFile -and !$RouteTablesCsvFile -and !$NsgsCsvFile ) {
				Write-Verbose "Importing setting from Yml file"
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject -and !$VnetsCsvFile -and !$RouteTablesCsvFile -and !$NsgsCsvFile ) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			$resourceGroupObjectArray = [System.Collections.ArrayList]@()

			# Code to Create Object from CSV

			if ($VnetsCsvFile -or $RouteTablesCsvFile -or $NsgsCsvFile -and !$SettingsObject)	{

				if ($VnetsCsvFile) {
					Write-Verbose "Vnet CSV Found."
					$VnetsCsvFile = Resolve-FilePath -NestedFile $VnetsCsvFile
					$vnetObjectFile = Import-Csv -Path $VnetsCsvFile

					if ($vnetObjectFile.count -eq 1) {
						$vnetFile = @($vnetObjectFile)
					}
					else {
						$vnetFile = $vnetObjectFile
					}
				}
				else {
					Write-Verbose "Vnet CSV not found."
					$vnetFile = @()
				}

				if ($RouteTablesCsvFile) {
					Write-Verbose "Route Table CSV Found."
					$RouteTablesCsvFile = Resolve-FilePath -NestedFile $RouteTablesCsvFile
					$routeTablesFile = Import-Csv -Path $RouteTablesCsvFile
				}
				else {
					Write-Verbose "Route Table CSV not Found."
					$routeTablesFile = @()
				}

				if ($NsgsCsvFile) {
					Write-Verbose "Nsg CSV Found."
					$NsgsCsvFile = Resolve-FilePath -NestedFile $NsgsCsvFile
					$nsgFile = Import-Csv -Path $NsgsCsvFile
				}
				else {
					Write-Verbose "Nsg CSV Not Found."
					$nsgFile = @()
				}

				if ($ResourceGroupsCsvFile) {
					Write-Verbose "Resource Group CSV Found."
					$ResourceGroupsCsvFile = Resolve-FilePath -NestedFile $ResourceGroupsCsvFile
					$resourceGroupslocation = Import-Csv -Path $ResourceGroupsCsvFile
				}

				Write-Verbose "Starting file merge."
				[System.Collections.ArrayList]$mergedFile = $vnetFile + $nsgFile + $routeTablesFile

				if ($nsgFile) {

					$nsgCsv = $mergedFile | Group-Object nsgName

					foreach ($nsg in ($nsgCsv | Where-Object { $_.name -like "*.csv" } )) {
						Write-Verbose "NSG: external CSV detected"

						foreach ($externalNsg in $nsg.Group) {

							$interimNsgCsvPath = "$(Split-Path $NsgsCsvFile)/$($nsg.Name)"
							$interimNsgCsvPath | Write-Verbose
							$interimNsgFile = Import-Csv -Path $interimNsgCsvPath
							$interimNsg = $interimNsgFile | Group-Object nsgName
							$interimNsgObjectArray = [System.Collections.ArrayList]@()

							foreach ($internalNsg in $interimNsg.Group) {

								$interimNsgObject = New-Object -TypeName psobject -Property @{
									"resourceGroupName"           = $internalNsg.resourceGroupName;
									"nsgName"                     = $internalNsg.nsgName;
									"location"                    = $internalNsg.location;
									"servicePublish"              = $internalNsg.servicePublish;
									"resourceGroupServicePublish" = $internalNsg.resourceGroupServicePublish;
									"storageServiceDependency"    = $internalNsg.storageServiceDependency;
									"workspaceServiceDependency"  = $internalNsg.workspaceServiceDependency;
									"ruleName"                    = $externalNsg.ruleName;
									"priority"                    = $externalNsg.priority;
									"direction"                   = $externalNsg.direction;
									"sourceIp"                    = $externalNsg.sourceIp;
									"sourcePort"                  = $externalNsg.sourcePort;
									"destinationIp"               = $externalNsg.destinationIp;
									"destinationPort"             = $externalNsg.destinationPort;
									"protocol"                    = $externalNsg.protocol;
									"Access"                      = $externalNsg.Access;
									"Description"                 = $externalNsg.Description
								}

								$interimNsgObjectArray.add($interimNsgObject) > $Null
							}

							Write-Verbose "Starting merge.."
							$mergedFile.Remove($externalNsg)
							$mergedFile += $interimNsgObjectArray
						}
					}
				}

				$resourceGroupsFile = $mergedFile | Group-Object -Property resourceGroupName

				# Code to add vnet in the object
				function subnetObject {
					param(
						[Object]$subnetGroup,
						[String]$subnetName
					)

					$subnetObject = @{
						subnetName           = $subnetName;
						cidr                 = $subnetGroup.cidr;
						networkSecurityGroup = $subnetGroup.networkSecurityGroup;
						routeTable           = $subnetGroup.routeTable;
					}
					$subnetObject
				}

				function vnetObject {
					param(
						[Object]$vnetGroup,
						[String]$vnetName
					)

					$subnetObjectList = [System.Collections.ArrayList]@()
					$subnetGroup = $vnetGroup | Group-Object subnetName

					foreach ($subnet in $subnetGroup) {
						$subnetObject = subnetObject -subnetGroup $subnet.Group -subnetName $subnet.Name
						$subnetObjectList.Add($subnetObject) > $Null
					}

					if ($vnetGroup.addressSpace -is [array]) {
						$addressSpace = $vnetGroup.addressSpace[0].ToString().split('|')
					}
					else {
						$addressSpace = $vnetGroup.addressSpace.ToString().split('|')
					}

					if ($vnetGroup.dnsServers -and $vnetGroup.dnsServers -ne '') {

						if ($vnetGroup.dnsServers -is [array]) {
							$dnsServers = $vnetGroup.dnsServers[0].ToString().split('|')
						}
						else {
							$dnsServers = $vnetGroup.dnsServers.ToString().split('|')
						}
					}
					else {
						$dnsServers = ""
					}

					if ($vnetGroup.virtualnetworkpeers -and $vnetGroup.virtualnetworkpeers -ne '') {

						if ($vnetGroup.virtualnetworkpeers -is [array]) {
							$virtualnetworkpeers = $vnetGroup.virtualnetworkpeers[0].ToString().split('|')
						}
						else {
							$virtualnetworkpeers = $vnetGroup.virtualnetworkpeers.ToString().split('|')
						}
					}
					else {
						$virtualnetworkpeers = @()
					}

					if ($vnetGroup.location -is [array]) {
						$location = $vnetGroup.location[0]
					}
					else {
						$location = $vnetGroup.location
					}

					if ($vnetGroup.servicePublish -is [array]) {
						$servicePublish = $vnetGroup.servicePublish[0]
					}
					else {
						$servicePublish = $vnetGroup.servicePublish
					}

					if ($vnetGroup.resourceGroupServicePublish -is [array]) {
						$resourceGroupServicePublish = $vnetGroup.resourceGroupServicePublish[0]
					}
					else {
						$resourceGroupServicePublish = $vnetGroup.resourceGroupServicePublish
					}

					$vnetObject = @{
						vnetName            = $vnetName;
						addressSpace        = $addressSpace;
						dnsServers          = $dnsServers;
						subnets             = $subnetObjectList;
						location            = $location;
						virtualnetworkpeers = $virtualnetworkpeers
						service             = @{
							publish = @{
								vnet          = $servicePublish;
								resourceGroup = $resourceGroupServicePublish
							}
						}
					}

					$vnetObject
				}

				# Code to add UDR in the object
				function routeObject {
					param(
						[Object]$routeGroup,
						[String]$routeName
					)

					$routeObject = @{
						routeName        = $routeName;
						cidr             = $routeGroup.cidr;
						nextHopType      = $routeGroup.nextHopType;
						nextHopIpAddress = $routeGroup.nextHopIpAddress
					}

					$routeObject
				}
				function routeTableObject {
					param(
						[Object]$routeTableGroup,
						[String]$tableName
					)

					$routeObjectList = [System.Collections.ArrayList]@()
					$routeGroup = $routeTableGroup | Group-Object routeName

					foreach ($route in $routeGroup) {
						$routeObject = routeObject -routeGroup $route.Group -routeName $route.Name
						$routeObjectList.Add($routeObject) > $Null
					}

					if ($routeTableGroup.location -is [array]) {
						$location = $routeTableGroup.location[0]
					}
					else {
						$location = $routeTableGroup.location
					}

					if ($routeTableGroup.routePropagation -is [array]) {
						$routePropagation = $routeTableGroup.routePropagation[0]
					}
					else {
						$routePropagation = $routeTableGroup.routePropagation
					}

					[bool]::TryParse($routePropagation, [ref]$routePropagation)  > $Null

					if ($routeTableGroup.servicePublish -is [array]) {
						$servicePublish = $routeTableGroup.servicePublish[0]
					}
					else {
						$servicePublish = $routeTableGroup.servicePublish
					}

					if ($routeTableGroup.resourceGroupServicePublish -is [array]) {
						$resourceGroupServicePublish = $routeTableGroup.resourceGroupServicePublish[0]
					}
					else {
						$resourceGroupServicePublish = $routeTableGroup.resourceGroupServicePublish
					}

					$routeTableObject = @{
						tableName        = $tableName;
						routePropagation = $routePropagation;
						routes           = $routeObjectList;
						location         = $location;
						service          = @{
							publish = @{
								routeTable    = $servicePublish;
								resourceGroup = $resourceGroupServicePublish
							}
						}
					}

					$routeTableObject
				}

				# Code to add Nsg rules in the object
				function nsgruleObject {
					param(
						[Object]$nsgGroupObject
					)

					$nsgruleObject = @{
						ruleName        = $nsgGroupObject.ruleName;
						Description     = $nsgGroupObject.Description;
						priority        = $nsgGroupObject.priority;
						direction       = $nsgGroupObject.direction;
						sourceIp        = $nsgGroupObject.sourceIp.ToString().split(',');
						sourcePort      = $nsgGroupObject.sourcePort.ToString().split(',');
						destinationIp   = $nsgGroupObject.destinationIp.ToString().split(',');
						destinationPort = $nsgGroupObject.destinationPort.ToString().split(',');
						protocol        = $nsgGroupObject.protocol;
						Access          = $nsgGroupObject.Access
					}

					$nsgruleObject
				}

				function nsgObject {
					param(
						[Object]$nsgGroup,
						[String]$nsgName
					)

					$nsgruleObjectList = [System.Collections.ArrayList]@()
					$nsgGroupObject = $nsgGroup | Group-Object ruleName

					foreach ($nsg in $nsgGroupObject) {

						if ($nsg -is [array]) {
							Write-Error "Rule name not unique : '$($nsg.Name) in '$($nsg.Group.nsgName[0])' for Resource Group: '$($nsg.Group.resourceGroupName[0])'" -CategoryTargetName $nsg.Name -ErrorAction Stop
						}
						$nsgruleObject = nsgruleObject -nsgGroupObject $nsg.Group
						$nsgruleObjectList.Add($nsgruleObject) > $Null
					}

					if ($nsgGroup.location -is [array]) {
						$location = $nsgGroup.location[0]
					}
					else {
						$location = $nsgGroup.location
					}

					if ($nsgGroup.servicePublish -is [array]) {
						$servicePublish = $nsgGroup.servicePublish[0]
					}
					else {
						$servicePublish = $nsgGroup.servicePublish
					}

					if ($nsgGroup.resourceGroupServicePublish -is [array]) {
						$resourceGroupServicePublish = $nsgGroup.resourceGroupServicePublish[0]
					}
					else {
						$resourceGroupServicePublish = $nsgGroup.resourceGroupServicePublish
					}

					if ($nsgGroup.storageServiceDependency -is [array]) {
						$storageServiceDependency = $nsgGroup.storageServiceDependency[0]
					}
					else {
						$storageServiceDependency = $nsgGroup.storageServiceDependency
					}

					if ($nsgGroup.workspaceServiceDependency -is [array]) {
						$workspaceServiceDependency = $nsgGroup.workspaceServiceDependency[0]
					}
					else {
						$workspaceServiceDependency = $nsgGroup.workspaceServiceDependency
					}

					$nsgObject = @{
						nsgName  = $nsgName;
						rules    = $nsgruleObjectList;
						location = $location;
						service  = @{
							publish      = @{
								networkSecurityGroup = $servicePublish;
								resourceGroup        = $resourceGroupServicePublish
							};
							dependencies = @{
								storage   = $storageServiceDependency;
								workspace = $workspaceServiceDependency;
							}
						}
					}

					$nsgObject
				}

				# Create a unified Resource Group collection
				foreach ($ResourceGroup in ($resourceGroupsFile | Where-Object { $_.Name -notlike '' })) {

					if ($ResourceGroup.Name) {

						Write-Verbose "working for $($ResourceGroup.Name)"

						# Adding Vnets
						if ($VnetsCsvFile) {

							$vnetsGroup = $ResourceGroup.Group | Group-Object vnetName

							$vnetObjectArray = [System.Collections.ArrayList]@()

							if (!$vnetsGroup.name) {
								Write-Warning "No virtual networks found for $($ResourceGroup.Name)."
							}
							else {
								Write-Verbose "'$($ResourceGroup.Name)' has vnets = '$($($vnetsGroup.Name -notlike '').count)'"

								foreach ($vnet in $vnetsGroup) {

									if ($vnet.name) {
										$vnetObject = vnetObject -vnetGroup $vnet.Group -vnetName $vnet.Name
										Write-Verbose "Adding vnet = '$($vnet.Name)' to RG = '$($ResourceGroup.Name)'"
										$vnetObjectArray.Add($vnetObject) > $Null
									}
								}
							}
						}

						# Adding UDR
						if ($RouteTablesCsvFile) {

							$routeTableGroup = $ResourceGroup.Group | Group-Object tableName

							$routeTableObjectArray = [System.Collections.ArrayList]@()

							if (!$routeTableGroup.name) {
								Write-Warning "No route tables found for $($ResourceGroup.Name)."
							}
							else {
								Write-Verbose "'$($ResourceGroup.Name)' has route tables = '$($($routeTableGroup.Name -notlike '').count)'"

								foreach ($routeTable in $routeTableGroup) {

									if ($routeTable.name) {
										$routeTableObject = routeTableObject -routeTableGroup $routeTable.Group -tableName $routeTable.Name
										Write-Verbose "Adding UDR = '$($routeTable.Name)' to RG = '$($ResourceGroup.Name)'"
										$routeTableObjectArray.Add($routeTableObject) > $Null
									}
								}
							}
						}

						# Adding NSG
						if ($NsgsCsvFile) {

							$nsgGroup = $ResourceGroup.Group | Group-Object nsgName

							$nsgObjectArray = [System.Collections.ArrayList]@()

							if (!$nsgGroup.name) {
								Write-Warning "No network security groups found for $($ResourceGroup.Name)."
							}
							else {
								Write-Verbose "'$($ResourceGroup.Name)' has network security groups = '$($($nsgGroup.Name -notlike '').count)'"

								foreach ($nsg in $nsgGroup) {

									if ($nsg.name) {
										$nsgObject = nsgObject -nsgGroup $nsg.Group -nsgName $nsg.Name
										Write-Verbose "Adding nsg = '$($nsg.Name)' to RG = '$($ResourceGroup.Name)'"
										$nsgObjectArray.Add($nsgObject) > $Null
									}
								}
							}
						}

						# Default values if required for ARM template sanity checks
						if (!$vnetObjectArray) {
							$vnetObjectArray = @(@{vnetName = "none"; vnetPeerings = @(); location = ""; dnsServers = ""; addressSpace = @("10.10.0.0/24"); subnets = @(@{subnetName = "none"; cidr = "0.0.0.0/0" }); service = @{publish = @{vnet = "" } } })
						}

						if (!$routeTableObjectArray) {
							$routeTableObjectArray = @(@{tableName = "none"; location = ""; routes = @(@{routeName = "none"; cidr = "0.0.0.0/0"; nextHopType = "VirtualAppliance"; nextHopIpAddress = "10.10.10.10" }); service = @{publish = @{routeTable = "" } } })
						}

						if (!$nsgObjectArray) {
							$nsgObjectArray = @(@{nsgName = "none"; location = ""; rules = @(@{ruleName = "none"; description = "none"; priority = "none"; direction = "none"; sourceIp = "10.10.10.10"; sourcePort = 3389; destinationIp = "10.10.10.11"; destinationPort = 3389; protocol = "Tcp"; Access = "allow" }); service = @{publish = @{networkSecurityGroup = "" } } })
						}

						# Build Resource Group Config
						$ifResourceGroupExists = Get-AzResourceGroup -Name $ResourceGroup.Name -ErrorAction SilentlyContinue

						if (!$ifResourceGroupExists) {

							$RGlocation = ($resourceGroupslocation | Where-Object { $_.resourceGroupName -like $ResourceGroup.Name }).location
							$resourceGroupServicePublish = ($resourceGroupslocation | Where-Object { $_.resourceGroupName -like $ResourceGroup.Name }).resourceGroupServicePublish

							if (!$RGlocation -and $vnetObjectArray[0].location ) {
								$RGlocation = $vnetObjectArray[0].location
							}

							if (!$RGlocation) {
								Write-Error "Resource Group $($ResourceGroup.Name) doesnt exist and a location is also not provided to create one."
							}

							if (!$resourceGroupServicePublish) {
								$resourceGroupServicePublish = $vnetObjectArray.service.publish.resourceGroup | Where-Object { $_ -notlike '' }
							}
							if (!$resourceGroupServicePublish) {
								$resourceGroupServicePublish = $routeTableObjectArray.service.publish.resourceGroup | Where-Object { $_ -notlike '' }
							}
							if (!$resourceGroupServicePublish) {
								$resourceGroupServicePublish = $nsgObjectArray.service.publish.resourceGroup | Where-Object { $_ -notlike '' }
							}

							if (!$resourceGroupServicePublish) {
								Write-Error "Resource Group $($ResourceGroup.Name) doesn't exist and need to be created. Please provide Resource Group Service to Publish."
							}

							if ($resourceGroupServicePublish -is [array]) {
								[String]$resourceGroupServicePublishString = $resourceGroupServicePublish[0]
							}
							else {
								[String]$resourceGroupServicePublishString = $resourceGroupServicePublish
							}

							$createRG = $true

							$service = @{
								publish = @{
									resourceGroup = $resourceGroupServicePublishString
								}
							}
						}
						else {
							$RGlocation = $ifResourceGroupExists.location
							$createRG = $false
							$service = @{
								publish = @{
									resourceGroup = "none"
								}
							}
						}

						# Adding Objects to resourceGroup Object
						Write-Verbose "Adding '$($ResourceGroup.Name)' to Resource Group Object List"
						$ResourceGroupObject = @{

							resourceGroup         = @{
								name     = $ResourceGroup.Name;
								location = $RGlocation;
								service  = $service;
								createRG = $createRG;
							};

							vnets                 = $vnetObjectArray;
							routeTables           = $routeTableObjectArray;
							networkSecurityGroups = $nsgObjectArray
						}

						$resourceGroupObjectArray.Add($ResourceGroupObject) > $Null
						Write-Verbose "'$($ResourceGroup.Name)' Added"
					}
				}
			}

			# Code to Create Object from Yml
			if ($SettingsObject) {

				function createNetworkObjectFromYml {
					param (
						[string]
						$YmlFilePath,
						[string]
						$ObjectType,
						[Boolean]
						$hasGroups
					)

					if ($_.contains('/') -or $_.contains('\')) {
						$interimPath = Resolve-FilePath -NestedFile $YmlFilePath
					}
					else {
						$interimPath = "$(Split-Path $SettingsFile)/$ObjectType/$YmlFilePath"
					}

					if (!$interimPath.contains('.yml')) {
						$interimPath = "$interimPath.yml"
					}

					try {
						$returnObject = Get-CmAzSettingsFile -Path $interimPath
					}
					catch {

						try {
							$interimPath.replace('/', '\')
							$returnObject = Get-CmAzSettingsFile -Path $interimPath
						}
						catch {
							throw "Not able to find file $YmlFilePath"
						}

					}

					if ($hasGroups) {

						ForEach ($object in $returnObject) {

							if ($ObjectType -eq "networkSecurityGroups") {
								$groupName = "ruleGroup"
								$childObject = "rules"
							}
							elseif ($ObjectType -eq "routeTables") {
								$groupName = "routeGroup"
								$childObject = "routes"
							}

							if ($object.$groupName) {

								$object.$groupName | ForEach-Object {

									try {
										$interimGroupPath = "$(Split-Path $interimPath)/groups/$_"

										if (!$interimGroupPath.contains('.yml')) {
											$interimGroupPath = "$interimGroupPath.yml"
										}

										$returnObjectGroup = Get-CmAzSettingsFile -Path $interimGroupPath
									}
									catch [System.Management.Automation.RuntimeException] {

										try {
											$interimGroupPath.replace('/', '\')
											$returnObjectGroup = Get-CmAzSettingsFile -Path $interimGroupPath
										}
										catch {
											throw "Not able to find file at $interimGroupPath."
										}

									}

									$object.$childObject += $returnObjectGroup
								}

								$object.remove($groupName)
							}
						}
					}

					return $returnObject
				}

				$SettingsObject.networking | ForEach-Object {
					$vnetObjectArray = [System.Collections.ArrayList]@()
					$routeTableObjectArray = [System.Collections.ArrayList]@()
					$nsgObjectArray = [System.Collections.ArrayList]@()

					$ResourceGroup = $_.ResourceGroupName

					$GlobalServiceContainer = $_

					# Set Vnet object
					if ($_.vnets) {

						Write-Verbose "Importing virtual networks ..."

						$_.vnets | ForEach-Object {

							$vnetObjectYml = createNetworkObjectFromYml -YmlFilePath $_ -ObjectType "vnets" -hasGroups $false

							if (!$vnetObjectYml.subnets) {
								Write-Error "$($vnetObjectYml.vnetName) is missing subnet configuration."
							}

							$vnetObjectYml.subnets | Where-Object { !$_.networkSecurityGroup } | ForEach-Object {
								$_.networkSecurityGroup = ""
							}

							$vnetObjectYml.subnets | Where-Object { !$_.routeTable } | ForEach-Object {
								$_.routeTable = ""
							}

							$vnetObjectYml | Where-Object { !$_.location } | ForEach-Object {
								$_.location = ""
							}

							$vnetObjectYml | Where-Object { !$_.dnsServers } | ForEach-Object {
								$_.dnsServers = ""
							}

							$vnetObjectYml | Where-Object { !$_.virtualNetworkPeers } | ForEach-Object {
								$_.virtualNetworkPeers = @()
							}

							$vnetObjectYml | ForEach-Object {
								Set-GlobalServiceValues -GlobalServiceContainer $GlobalServiceContainer  -ServiceKey "vnet" -ResourceServiceContainer $_
							}

							$vnetObjectArray += $vnetObjectYml
							Write-Verbose "Vnets from $_ added to '$ResourceGroup'"
						}
					}

					# Set Route Table Object
					if ($_.routeTables) {

						Write-Verbose "Importing route tables..."

						$_.routeTables | ForEach-Object {

							$routeTableObjectYml = createNetworkObjectFromYml -YmlFilePath $_ -ObjectType "routeTables" -hasGroups $true

							$routeTableObjectYml | Where-Object { !$_.location } | ForEach-Object {
								$_.location = ""
							}

							$routeTableObjectYml | Where-Object { !$_.routePropagation } | ForEach-Object {
								$_.routePropagation = $false
							}

							$routeTableObjectYml | ForEach-Object {
								Set-GlobalServiceValues -GlobalServiceContainer $GlobalServiceContainer -ServiceKey "routeTable" -ResourceServiceContainer $_
							}

							$routeTableObjectArray += $routeTableObjectYml
							Write-Verbose "Route tables from $_ added to '$ResourceGroup'"
						}
					}

					# Set network Security group Object
					if ($_.networkSecurityGroups) {

						Write-Verbose "Importing network security groups..."

						$_.networkSecurityGroups | ForEach-Object {

							$nsgObjectYml = createNetworkObjectFromYml -YmlFilePath $_ -ObjectType "networkSecurityGroups" -hasGroups $true

							$nsgObjectYml | Where-Object { !$_.location } | ForEach-Object {
								$_.location = ""
							}

							$nsgObjectYml | ForEach-Object {
								Set-GlobalServiceValues -GlobalServiceContainer $GlobalServiceContainer  -ServiceKey "networkSecurityGroup" -ResourceServiceContainer $_
							}

							$nsgObjectArray += $nsgObjectYml
							Write-Verbose "Network Security Groups from $_ added to '$ResourceGroup'"
						}
					}

					# Default values if required for ARM template sanity checks
					if (!$vnetObjectArray) {
						$vnetObjectArray = @(@{vnetName = "none"; vnetPeerings = @(); location = ""; dnsServers = ""; addressSpace = @("10.10.0.0/24"); subnets = @(@{subnetName = "none"; cidr = "0.0.0.0/0" }); service = @{publish = @{vnet = "" } } })
					}

					if (!$routeTableObjectArray) {
						$routeTableObjectArray = @(@{tableName = "none"; location = ""; routes = @(@{routeName = "none"; cidr = "0.0.0.0/0"; nextHopType = "VirtualAppliance"; nextHopIpAddress = "10.10.10.10" }); service = @{publish = @{routeTable = "" } } })
					}

					if (!$nsgObjectArray) {
						$nsgObjectArray = @(@{nsgName = "none"; location = ""; rules = @(@{ruleName = "none"; description = "none"; priority = "none"; direction = "none"; sourceIp = "10.10.10.10"; sourcePort = 3389; destinationIp = "10.10.10.11"; destinationPort = 3389; protocol = "Tcp"; Access = "allow" }); service = @{publish = @{networkSecurityGroup = "" } } })
					}

					# Build Resource Group Config
					$ifResourceGroupExists = Get-AzResourceGroup -Name $_.resourceGroupName -ErrorAction SilentlyContinue

					if (!$ifResourceGroupExists) {
						$RGlocation = $_.location

						if (!$RGlocation -and $vnetObjectArray[0].location ) {
							$RGlocation = $vnetObjectArray[0].location
						}

						if (!$RGlocation) {
							Write-Error "Resource Group $($_.resourceGroupName) doesnt exist and a location is also not provided to create one."
						}

						if (!$_.service.publish.resourceGroup) {
							Write-Error "Resource Group doesn't exist and need to be created. Please provide Resource Group Service to Publish."
						}

						$createRG = $true

						$service = @{
							publish = @{
								resourceGroup = $_.service.publish.resourceGroup
							}
						}
					}
					else {
						$RGlocation = $ifResourceGroupExists.location
						$createRG = $false
						$service = @{
							publish = @{
								resourceGroup = ""
							}
						}
					}

					# Adding Objects to resourceGroup Object
					Write-Verbose "Adding '$ResourceGroup' to Resource Group Object List"
					$ResourceGroupObject = @{

						resourceGroup         = @{
							name     = $ResourceGroup;
							location = $RGlocation;
							createRG = $createRG;
							service  = $service
						};

						vnets                 = $vnetObjectArray;
						routeTables           = $routeTableObjectArray;
						networkSecurityGroups = $nsgObjectArray
					}

					$resourceGroupObjectArray.Add($ResourceGroupObject) > $Null
					Write-Verbose "'$ResourceGroup' Added"
				}
			}

			# Arm Deployment
			Write-Verbose "Deploying resource groups..."

			$deploymentNameRg = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $resourceGroupObjectArray[0].resourceGroup.location -Name "New-CmAzIaasNetworking-RGs"

			New-AzDeployment `
				-Name $deploymentNameRg `
				-TemplateFile $PSScriptRoot\New-CmAzIaasNetworking.ResourceGroups.json `
				-Location $resourceGroupObjectArray[0].resourceGroup.location `
				-NetworkingArrayObject $resourceGroupObjectArray

			if ($resourceGroupObjectArray.networkSecurityGroups.nsgName[0] -ne 'none' -and $resourceGroupObjectArray.networkSecurityGroups.nsgName -ne 'none') {

				Write-Verbose "Nsgs found..."

				$storageServiceDependency = $SettingsObject.service.dependencies.storage
				$workspaceServiceDependency = $SettingsObject.service.dependencies.workspace

				if (!$storageServiceDependency) {

					if ($resourceGroupObjectArray.networkSecurityGroups.service.dependencies.storage -is [array]) {
						$storageServiceDependency = $resourceGroupObjectArray.networkSecurityGroups.service.dependencies.storage[0]
					}
					else {
						$storageServiceDependency = $resourceGroupObjectArray.networkSecurityGroups.service.dependencies.storage
					}
				}

				if (!$workspaceServiceDependency) {

					if ($resourceGroupObjectArray.networkSecurityGroups.service.dependencies.workspace -is [array]) {
						$workspaceServiceDependency = $resourceGroupObjectArray.networkSecurityGroups.service.dependencies.workspace[0]
					}
					else {
						$workspaceServiceDependency = $resourceGroupObjectArray.networkSecurityGroups.service.dependencies.workspace
					}
				}

				if (!$storageServiceDependency) {
					Write-Error "Please provide a storage service value." -Category InvalidArgument
				}

				if (!$workspaceServiceDependency) {
					Write-Error "Please provide a workspace service value." -Category InvalidArgument
				}

				$storageAccounts = Get-CmAzService -Service $storageServiceDependency -ThrowIfUnavailable
				$workspace = Get-CmAzService -Service $workspaceServiceDependency -ThrowIfUnavailable -ThrowIfMultiple

				foreach ($resourceGroupObject in $resourceGroupObjectArray) {

					foreach ($nsg in $resourceGroupObject.networkSecurityGroups) {

						$nsg.resourceGroup = $resourceGroupObject.resourceGroup

						if (!$nsg.location) {
							$nsg.location = $resourceGroupObject.resourceGroup.location
						}

						$filteredStorageAccounts = $storageAccounts | Where-Object { $_.location -eq $nsg.location }

						if ($filteredStorageAccounts -Is [array]) {
							$filteredStorageAccounts = $filteredStorageAccounts[0]
						}

						$nsg.storageAccountId = $filteredStorageAccounts.id
					}
				}

				$networkWatcherResourceGroupName = "NetworkWatcherRG"

				$ifResourceGroupExists = Get-AzResourceGroup -Name $networkWatcherResourceGroupName  -ErrorAction SilentlyContinue

				if (!$ifResourceGroupExists) {

					Write-Verbose "Creating new Network Watcher Resource Group: $($networkWatcherResourceGroupName)..."
					New-AzResourceGroup -Location $workspace.location -Name $networkWatcherResourceGroupName -Force
				}
				else {
					Write-Verbose "$($networkWatcherResourceGroupName): Already exists..."
				}

				Write-Verbose "Deploying nsgs..."

				$deploymentNameNsg = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $workspace.location -Name "New-CmAzIaasNetworking-Nsgs"

				New-AzDeployment `
					-Name $deploymentNameNsg `
					-TemplateFile $PSScriptRoot\New-CmAzIaasNetworking.Nsgs.json `
					-Location $workspace.location `
					-Locations (($resourceGroupObjectArray.networkSecurityGroups | Where-Object { $_.nsgname -ne "none" } ).location | Sort-Object | Get-Unique) `
					-NetworkWatcherResourceGroupName $networkWatcherResourceGroupName `
					-Nsgs ($resourceGroupObjectArray.networkSecurityGroups | Where-Object { $_.nsgname -ne "none" }) `
					-Workspace $workspace
			}

			Write-Verbose "Deploying vnets and udrs..."

			$deploymentNameVu = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $resourceGroupObjectArray[0].resourceGroup.location -Name "New-CmAzIaasNetworking-VUs"

			New-AzDeployment `
				-Name $deploymentNameVu `
				-TemplateFile $PSScriptRoot\New-CmAzIaasNetworking.json `
				-Location $resourceGroupObjectArray[0].resourceGroup.location `
				-NetworkingArrayObject $resourceGroupObjectArray

			if ($resourceGroupObjectArray.vnets.virtualnetworkpeers) {
				$filteredVnetObject = $resourceGroupObjectArray.vnets | Where-Object { $_.virtualnetworkpeers }
				$vnetPeeringsObjectArray = [System.Collections.ArrayList]@()

				foreach ($Vnet in $filteredVnetObject) {

					foreach ($peeringVnet in $Vnet.virtualnetworkpeers) {

						$currentVnetObject = $resourceGroupObjectArray | Where-Object { $_.vnets.vnetname -eq $Vnet.vnetname }
						$peeringVnetObject = $resourceGroupObjectArray | Where-Object { $_.vnets.vnetname -eq $peeringVnet }

						$vnetPeeringsObject = @{

							sourceVnetRg           = $currentVnetObject.resourceGroup.name
							sourceVnetName         = $Vnet.vnetname
							TargetVnetName         = $peeringVnet
							TargetVnetRg           = $peeringVnetObject.resourceGroup.name
							TargetVnetAddressSpace = $peeringVnetObject.vnets.addressSpace
						}

						$vnetPeeringsObjectArray.Add($vnetPeeringsObject) > $Null
					}
				}

				Write-Verbose "Configuring vnet peerings..."

				$deploymentNamePeerings = Get-CmAzResourceName -Resource "Deployment" -Architecture "IaaS" -Region $resourceGroupObjectArray[0].resourceGroup.location -Name "New-CmAzIaasNetworking-Vps"

				New-AzDeployment `
					-Name $deploymentNamePeerings `
					-TemplateFile $PSScriptRoot\New-CmAzIaasNetworking.vnetPeerings.json `
					-Location $resourceGroupObjectArray[0].resourceGroup.location `
					-VnetPeeringsObjectArray $vnetPeeringsObjectArray
			}

			$resourceGroupsToSet = @()
			$resourceGroupsToSet += $networkWatcherResourceGroupName
			$resourceGroupsToSet += ($resourceGroupObjectArray.resourceGroup | Where-Object -Property createRG -eq $true).name

			if ($resourceGroupsToSet) {

				Write-Verbose "Started tagging for resourcegroups..."
				Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceGroupIds $resourceGroupsToSet
			}

			[System.Collections.ArrayList]$resourcesToSet = @()

			$resourcesToSet += $resourceGroupObjectArray.vnets.vnetName | Where-Object { $_ -ne "none" }
			$resourcesToSet += $resourceGroupObjectArray.networkSecurityGroups.nsgName | Where-Object { $_ -ne "none" }
			$resourcesToSet += $resourceGroupObjectArray.routeTables.tableName | Where-Object { $_ -ne "none" }

			Write-Verbose "Started tagging for resources..."
			Set-DeployedResourceTags -TagSettingsFile $TagSettingsFile -ResourceIds $resourcesToSet

			Write-Verbose "Finished."
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}
