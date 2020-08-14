function New-CmAzPaasSql {

	<#
		.Synopsis
		 Create SQL databases

		.Description
		 Completes following:
			* Creates SQL Server.
			* Creates databases.
			* Configures firewall (for postgres | mariaDB | mysql)
			* Enable log analytics (Optional)

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 PaaS

		.Example
		 New-CmAzPaasSql -SettingsFile ./sql.yml

		.Example
		 New-CmAzPaasSql -SettingsObject $settings
	#>

	[OutputType([System.Collections.ArrayList])]
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy SQL database")) {

			if ($SettingsFile -and -not $SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (-not $SettingsFile -and -not $SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			$resourceGroup = Get-CmAzService -Service $SettingsObject.resourceGroupServiceTag -IsResourceGroup -ThrowIfUnavailable
			if (!$SettingsObject.workSpaceServiceTag) {
				$workspace = @{"Name" = ""; "ResourceId" = ""; "Location" = "" }
			}
			else {
				Write-Verbose "Fetching workspace.."
				$workspace = Get-CmAzService -Service $SettingsObject.workSpaceServiceTag
			}

			if (!$SettingsObject.logRetentionPeriodInDays) {
				$logRetentionPeriodInDays = 30
			}
			else{
				$logRetentionPeriodInDays = $SettingsObject.logRetentionPeriodInDays
			}

			[system.Collections.ArrayList]$sqlObjectArray = @()
			[system.Collections.ArrayList]$sqlObjectArraySharedServer = @()
			$allSqlServerNames = $SettingsObject.sqlConfig.serverName

			$SettingsObject.sqlConfig | ForEach-Object {

				[System.Collections.ArrayList] $databases = @()

				if ($_.databaseNames) {

					foreach ($database in $_.databaseNames) {
						$databases.Add((Get-CmAzResourceName -Resource "AzureSQLDatabase" -Architecture "PaaS" -Region $SettingsObject.Location -Name $database)) > $Null
					}

				}
				else {
					$databases.Add((Get-CmAzResourceName -Resource "AzureSQLDatabase" -Architecture "PaaS" -Region $SettingsObject.Location -Name $_.serverName)) > $Null
				}

				$keyVaultName = Get-CmAzService -Service $_.keyvault.serviceTag

				$password = (Get-AzKeyVaultSecret -VaultName $keyVaultName.name -Name $_.keyvault.passwordSecretName).SecretValue
				$serverName = Get-CmAzResourceName -Resource "AzureSQLDatabaseserver" -Architecture "PaaS" -Region $SettingsObject.Location -Name $_.serverName

				$serverNameCheck = $_.serverName

				if ($_.type -eq "elasticpool" -and (($allSqlServerNames | Where-Object { $_ -match $serverNameCheck }).count -gt 1)) {
					$sharedServer = $true
				}
				else {
					$sharedServer = $false
				}

				$dbFamily = switch ($_.family) {

					azuresql {
						"Microsoft.Sql"
					}
					postgressql {
						"Microsoft.DBforPostgreSQL"
					}
					mariadb {
						"Microsoft.DBforMariaDB"
					}
					mysql {
						"Microsoft.DBforMySQL"
					}
					default { Write-Error "Please provide correct database family name. Choose from azuresql|postgressql|mariadb|mysql" }
				}

				if (!$_.firewallRules) {
					$_.firewallRules = @{
						"startIpAddress" = "0.0.0.0";
						"endIpAddress" = "255.255.255.255"
					}
				}

				if (!$_.type) {
					$_.type = "none"
				}

				$sqlObject = @{
					"data" = @{
						"family"                     = $dbFamily
						"sharedServer"               = $sharedServer
						"type"                       = ($_.type).Tolower()
						"serverName"                 = $serverName;
						"databases"                  = $databases;
						"sku"                        = $_.sku;
						"version"                    = $_version;
						"elasticPoolProperties"      = @{
							"collation"                     = "SQL_Latin1_General_CP1_CI_AS";
							"requestedServiceObjectiveName" = "ElasticPool";
							"elasticPoolName"               = "ep-$serverName";
						};
						"administratorLogin"         = $_.administratorLogin;
						"workspace"                  = $workspace;
						"logRetentionDays"           = $logRetentionPeriodInDays;
						"firewallRules"			     = $_.firewallRules
					};

					"administratorLoginPassword" = @{
							"keyVaultid" = $keyVaultName.resourceId;
							"secretName" = $_.keyvault.passwordSecretName
					}
				}

				if ($sqlObject.data.sharedServer) {
					($sqlObjectArraySharedServer).Add($sqlObject) > $Null
				}
				else {
					($sqlObjectArray).Add($sqlObject) > $Null
				}

			}

			$allsqlObjectArray = @($sqlObjectArray, $sqlObjectArraySharedServer)

			$allsqlObjectArray | ForEach-Object {

				if ($_) {

					switch ($_.data.sharedServer[0]) {
						"true" {
							$templateType = "Shared"
						}
						default {
							$templateType = "Parent"
						}
					}

					New-AzResourceGroupDeployment `
						-Name "Cm_SQL_$templateType" `
						-ResourceGroupName $resourceGroup.ResourceGroupName `
						-TemplateFile "$PSScriptRoot\New-CmAzPaasSql.json" `
						-SqlObjectArray $_ `
						-Location $SettingsObject.Location `
						-Force
				}
			}
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}
}
