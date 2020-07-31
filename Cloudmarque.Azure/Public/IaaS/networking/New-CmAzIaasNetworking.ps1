function New-CmAzIaasNetworking {
	<#
		.Synopsis
		Creates networking solution

		.Description
		Completes following:
			* Creates vnets and subnets. Optionally attach nsg and route tables to subnet.
			* Creates route tables and routes.
			* Creates network security groups.
			* Configure resources in mulitple resource groups at once.

		.Parameter SettingsFile
		File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		Object containing the configuration values required to run this cmdlet.

		.Parameter VnetCsvFile
		File path for the csv containing virtual network configurations.
		Required headers: resourceGroupName|Location|vnetName|addressSpace|subnetName|cidr|networkSecurityGroup|routeTable

		.Parameter RouteTableCsvFile
		File path for the csv containing route table configurations.
		Required headers: resourceGroupName|tableName|routeName|cidr|nextHopType|nextHopIpAddress|notes

		.Parameter NsgCsvFile
		File path for the csv containing virtual network security group configurations.
		Required headers: resourceGroupName|nsgName|ruleName|priority|direction|sourceIp|sourcePort|destinationIp|destinationPort|protocol|Access|Description

		.Component
		IaaS

		.Example
		New-CmAzIaasNetworking -settingsFile "networking.yml"

		.Example
		New-CmAzIaasNetworking -VnetCsvFile "vnet.csv" -RouteTableCsvFile "routeTable.csv" -NsgCsvFile "nsg.csv"

		.Example
		New-CmAzIaasNetworking -settingsObject $VnetSettings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings Yml File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$VnetCsvFile,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$RouteTableCsvFile,
		[parameter(Mandatory = $false, ParameterSetName = "Settings CSV File")]
		[String]$NsgCsvFile
	)

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Create networking solution")) {

			if ($SettingsFile -and -not $SettingsObject -and -not $VnetCsvFile -and -not $RouteTableCsvFile -and -not $NsgCsvFile ) {
				Write-Verbose "Importing setting from Yml file"
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (-not $SettingsFile -and -not $SettingsObject -and -not $VnetCsvFile -and -not $RouteTableCsvFile -and -not $NsgCsvFile ) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

  			# Code to Create Object from CSV

			$resourceGroupObjectArray = [System.Collections.ArrayList]@()

			if ($VnetCsvFile -or $RouteTableCsvFile -or $NsgCsvFile)	{
				if ($VnetCsvFile) {
					Write-Verbose "Vnet CSV Found!!"
					$vnetObjectFile = Import-Csv -Path $VnetCsvFile
					if ($vnetObjectFile.count -eq 1) {
						$vnetFile = @($vnetObjectFile)
					}
					else {
						$vnetFile = $vnetObjectFile
					}
				}
				else {
					Write-Verbose "Vnet CSV not found!!"
					$vnetFile = @($Null)
				}
				if ($RouteTableCsvFile) {
					Write-Verbose "Route Table CSV Found!!"
					$routeTablesFile = Import-Csv -Path $RouteTableCsvFile
				}
				else {
					Write-Verbose "Route Table CSV not Found!!"
					$routeTablesFile = @($Null)
				}
				if ($NsgCsvFile) {
					Write-Verbose "Nsg CSV Found!!"
					$nsgFile = Import-Csv -Path $NsgCsvFile
				}
				else {
					Write-Verbose "Nsg CSV Not Found!!"
					$nsgFile = @($Null)
				}
				Write-Verbose "starting file merge"
				[System.Collections.ArrayList]$mergedFile = $vnetFile + $nsgFile + $routeTablesFile

				if ($nsgFile) {
					$nsgCsv = $mergedFile | Group-Object nsgName
					foreach ($nsg in $nsgCsv) {
						if ($nsg.name -like "*.csv") {
							Write-Verbose "NSG: external CSV detected"
							foreach ($externalNsg in $nsg.Group) {
								$interimNsgCsvPath = "$(Split-Path $NsgCsvFile)/$($nsg.Name)"
								$interimNsgCsvPath | Write-Verbose
								$interimNsgFile = Import-Csv -Path $interimNsgCsvPath
								$interimNsg = $interimNsgFile | Group-Object nsgName
								$interimNsgObjectArray = [System.Collections.ArrayList]@()
								$interimNsgObject = New-Object -TypeName psobject
								foreach ($internalNsg in $interimNsg.Group) {
									$interimNsgObject = New-Object -TypeName psobject
									$interimNsgObject | add-member -MemberType NoteProperty -Name resourceGroupName -Value $internalNsg.resourceGroupName
									$interimNsgObject | add-member -MemberType NoteProperty -Name nsgName -Value $internalNsg.nsgName
									$interimNsgObject | add-member -MemberType NoteProperty -Name ruleName -Value $externalNsg.ruleName
									$interimNsgObject | add-member -MemberType NoteProperty -Name priority -Value $externalNsg.priority
									$interimNsgObject | add-member -MemberType NoteProperty -Name direction -Value $externalNsg.direction
									$interimNsgObject | add-member -MemberType NoteProperty -Name sourceIp -Value $externalNsg.sourceIp
									$interimNsgObject | add-member -MemberType NoteProperty -Name sourcePort -Value $externalNsg.sourcePort
									$interimNsgObject | add-member -MemberType NoteProperty -Name destinationIp -Value $externalNsg.destinationIp
									$interimNsgObject | add-member -MemberType NoteProperty -Name destinationPort -Value $externalNsg.destinationPort
									$interimNsgObject | add-member -MemberType NoteProperty -Name protocol -Value $externalNsg.protocol
									$interimNsgObject | add-member -MemberType NoteProperty -Name Access -Value $externalNsg.Access
									$interimNsgObject | add-member -MemberType NoteProperty -Name Description -Value $externalNsg.Description
									$interimNsgObjectArray.add($interimNsgObject) > $Null
								}
								Write-Verbose "starting merge"
								$mergedFile.Remove($externalNsg)
								$mergedFile += $interimNsgObjectArray
							}
						}
					}
				}

				$ResourceGroupsFile = $mergedFile | Group-Object -Property resourceGroupName

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
					if ($vnetGroup.addressSpace.count -gt 1) {
						$addressSpace = $vnetGroup.addressSpace[0].ToString().split(',')
					}
					else {
						$addressSpace = $vnetGroup.addressSpace.ToString().split(',')
					}
					if ($vnetGroup.Location.count -gt 1) {
						$Location = $vnetGroup.Location[0]
					}
					else {
						$Location = $vnetGroup.Location
					}
					$vnetObject = @{
						vnetName     = $vnetName;
						addressSpace = $addressSpace;
						subnets      = $subnetObjectList;
						Location     = $Location
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
					$routeTableObject = @{
						tableName = $tableName;
						routes    = $routeObjectList;
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
						if ($nsg.count -gt 1) {
							Write-Error "Rule name not unique : '$($nsg.Name) in '$($nsg.Group.nsgName[0])' for Resource Group: '$($nsg.Group.resourceGroupName[0])'" -CategoryTargetName $nsg.Name -ErrorAction Stop
						}
						$nsgruleObject = nsgruleObject -nsgGroupObject $nsg.Group
						$nsgruleObjectList.Add($nsgruleObject) > $Null
					}
					$nsgObject = @{
						nsgName = $nsgName;
						rules   = $nsgruleObjectList;
					}
					$nsgObject
				}

				# Create a unified Resource Group collection
				foreach ($ResourceGroup in $ResourceGroupsFile) {
					if ($ResourceGroup.Name) {
						# Adding Vnets
						Write-Verbose "working for $($ResourceGroup.Name)"
						$vnetsGroup = $ResourceGroup.Group | Group-Object vnetName
						Write-Verbose "'$($ResourceGroup.Name)' has vnets = '$($($vnetsGroup.Name -notlike '').count)'"
						$vnetObjectArray = [System.Collections.ArrayList]@()
						foreach ($vnet in $vnetsGroup) {
							if ($vnet.name) {
								$vnetObject = vnetObject -vnetGroup $vnet.Group -vnetName $vnet.Name
								Write-Verbose "Adding vnet = '$($vnet.Name)' to RG = '$($ResourceGroup.Name)'"
								$vnetObjectArray.Add($vnetObject) > $Null
							}
						}
						# Adding UDR
						$routeTableGroup = $ResourceGroup.Group | Group-Object tableName
						Write-Verbose "'$($ResourceGroup.Name)' has route tables = '$($($routeTableGroup.Name -notlike '').count)'"
						$routeTableObjectArray = [System.Collections.ArrayList]@()
						foreach ($routeTable in $routeTableGroup) {
							if ($routeTable.name) {
								$routeTableObject = routeTableObject -routeTableGroup $routeTable.Group -tableName $routeTable.Name
								Write-Verbose "Adding UDR = '$($routeTable.Name)' to RG = '$($ResourceGroup.Name)'"
								$routeTableObjectArray.Add($routeTableObject) > $Null
							}
						}
						# Adding NSG
						$nsgGroup = $ResourceGroup.Group | Group-Object nsgName
						Write-Verbose "'$($ResourceGroup.Name)' has route tables = '$($($nsgGroup.Name -notlike '').count)'"
						$nsgObjectArray = [System.Collections.ArrayList]@()
						foreach ($nsg in $nsgGroup) {
							if ($nsg.name) {
								$nsgObject = nsgObject -nsgGroup $nsg.Group -nsgName $nsg.Name
								Write-Verbose "Adding nsg = '$($nsg.Name)' to RG = '$($ResourceGroup.Name)'"
								$nsgObjectArray.Add($nsgObject) > $Null
							}
						}
						# Adding Objects to resourceGroup Object
						Write-Verbose "Adding '$($ResourceGroup.Name)' to Resource Group Object List"
						$ResourceGroupObject = @{
							resourceGroupName     = $ResourceGroup.Name;
							vnets                 = $vnetObjectArray;
							routeTables           = $routeTableObjectArray;
							networkSecurityGroups = $nsgObjectArray
						}
						$resourceGroupObjectArray.Add($ResourceGroupObject) > $Null
						Write-Verbose "'$($ResourceGroup.Name)' Added"
					}

				}
			}
			# Arm Deployment

			if ($SettingsObject -and -not $resourceGroupObjectArray) {
				$resourceGroupObjectArray = $SettingsObject.ResourceGroups.clone()
			}

			Write-Verbose "Initiating deployment"
			Write-Verbose "Setting environment Variables"

			$context = ""

			try {
				$env:PSScriptRoot = $PSScriptRoot
				$context = "context.json"
			}
			catch {
				write-verbose "Error setting environment variables. Make sure CmAzContext is set."
				$PSItem.ToString() | write-verbose
			}

			Save-Azcontext -Path $context -Force

			try {
				$resourceGroupObjectArray | ForEach-Object -Parallel {

					Write-Verbose "Importing context.."
					Import-Azcontext -Path $using:context > $null

					if ($_.resourceGroupName) {

						$ifResourceGroupExists = Get-AzResourceGroup -Name $_.resourceGroupName -ErrorAction SilentlyContinue

						if (!$ifResourceGroupExists) {
							New-AzResourceGroup -Name $_.resourceGroupName -Location "UK South" -Force
						}
						if (!$_.vnets) {
							$_.vnets = @(@{vnetName = "none"; location = "uksouth"; addressSpace = @("10.10.0.0/24"); subnets = @(@{subnetName = "none"; cidr = "0.0.0.0/0" }) })
						}
						if (!$_.routeTables) {
							$_.routeTables = @(@{tableName = "none"; routes = @(@{routeName = "none"; cidr = "0.0.0.0/0"; nextHopType = "VirtualAppliance"; nextHopIpAddress = "10.10.10.10" }) })
						}
						if (!$_.networkSecurityGroups) {
							$_.networkSecurityGroups = @(@{nsgName = "none"; rules = @(@{ruleName = "none"; description = "none"; priority = "none"; direction = "none"; sourceIp = "10.10.10.10"; sourcePort = 3389; destinationIp = "10.10.10.11"; destinationPort = 3389; protocol = "Tcp"; Access = "allow" }) })
						}
						Write-Verbose "Starting Deployment in Resourcegroup:'$($_.resourceGroupName)"

						New-AzResourceGroupDeployment `
							-Name "CmAz-Network-$((Get-Date -Format "yyyymmdd-hhmmss"))" `
							-TemplateFile "$env:PSScriptRoot\New-CmAzIaasNetworking.json" `
							-ResourceGroupName $_.resourceGroupName `
							-VnetArmObject $_.vnets `
							-RouteTableArmObject $_.routeTables `
							-NsgArmObject $_.networkSecurityGroups `
							-Force `
							-verbose
					}
				}
			}
			catch {
				$PSItem.ToString() | Write-Error
			}

			Write-Verbose "Finished!"
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSItem)
	}
}