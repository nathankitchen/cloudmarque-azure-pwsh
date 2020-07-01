function New-CmAzCoreAutomation {

	<#
		.Synopsis
		 Create an Automation account with runbooks.

		.Description
		 Completes the following:
			* Creates Resource Group for runbook, dsc or both.
			* Creates Automation account for runbook, dsc or both.
			* Creates Key vault certificate if not available.
			* Create RunAsAccount and RunAsCertificate for Automation accounts.
			* Optinally sync SCM source.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Core


		.Example
		 New-CmAzCoreAutomation -SettingsFile "c:/directory/settingsFile.yml"

		.Example
		 New-CmAzCoreAutomation -SettingsObject $settings
	#>

	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
	param(
		[parameter(Mandatory = $true, ParameterSetName = "Settings File")]
		[String]$SettingsFile,
		[parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
		[Object]$SettingsObject
	)
	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Cloudmarque Core Automation Stack")) {

			# Initializing settings file values

			$AzSubscription = Get-AzSubscription
			$ProjectContext = Get-CmAzContext -RequireAzure -ThrowIfUnavailable

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			foreach ($item in $SettingsObject.Automation.Keys) {

				$RandomValue = Get-Random -Minimum 1001 -Maximum 9999

				# Set Account Type
				if ($item -eq "dsc") {
					$accountType = "dsc"
				}
				elseif ($item -eq "runbook") {
					$accountType = "runbook"
				}
				else {
					Write-Error "$((get-date).TimeOfDay.ToString()) - Set type to be either runbook or dsc"
					Break
				}

				$Location = $SettingsObject.Location
				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Location set to $Location"
				Write-Verbose "creating automation account for $accountType"
				if (!$Location) {
					Write-Error "$((get-date).TimeOfDay.ToString()) - Location not found"
					Break
				}

				$keyVaultName = $SettingsObject.Automation.$accountType.KeyVaultName
				if (!$keyVaultName) {
					Write-Error "$((get-date).TimeOfDay.ToString()) - Provide Key Vault For Certificate"
					break
				}

				$keyVault = Get-AzKeyVault -VaultName $keyVaultName

				if (!$keyVault) {
					Write-Error "$((get-date).TimeOfDay.ToString()) - Key Vault $keyVaultName doesnt exist. Please provide existing Key Vault Name"
					Break
				}

				$certificateName = $SettingsObject.Automation.$accountType.CertificateName
				if (!$certificateName) {
					Write-Information "$((get-date).TimeOfDay.ToString()) - No KeyVault Certificate Provided.. A Generic certificate will be created"
					$certificateName = "$accountType-$RandomValue"
				}

				$keyVaultCertificatePassword = $SettingsObject.Automation.$accountType.KeyVaultCertificatePassword
				if (!$keyVaultCertificatePassword) {
					Write-Error "$((get-date).TimeOfDay.ToString()) - No keyVault path or Password provided for Certificate...."
					break
				}

				if ($SettingsObject.Automation.$accountType.RepoUrl) {

					$repoUrl = $SettingsObject.Automation.$accountType.RepoUrl
					$repoType = $SettingsObject.Automation.$accountType.RepoType
					$folderPath = $SettingsObject.Automation.$accountType.FolderPath
					$keyVaultPersonalAccessToken = $SettingsObject.Automation.$accountType.KeyVaultPersonalAccessToken

					if (!$keyVaultPersonalAccessToken) {
						Write-Error "$((get-date).TimeOfDay.ToString()) - No keyVault path or Password provided for Personal Access Token...."
						break
					}

					$PersonalAccessToken = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultPersonalAccessToken).SecretValue
					if (!$PersonalAccessToken) {
						Write-Error "$((get-date).TimeOfDay.ToString()) - No PAT found on key vault"
					}
				}
				else {
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - No Repository provided $accountType"
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - SCM Intergration will be skipped ... "
				}


				$nameResourceGroup = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region $Location -Name "Automation-$accountType"
				$resourceGroup = New-AzResourceGroup -ResourceGroupName $nameResourceGroup -Location $Location -Force
				Write-Verbose "$((get-date).TimeOfDay.ToString())  - Resource Group Created ......  $nameResourceGroup"
				$resourceGroup | Write-Verbose

				# Creating Automation accountname using name generator
				$automationAccountName = Get-CmAzResourceName -Resource "Automation" -Architecture "Core" -Region $Location -Name $accountType

				# create Automation account
				New-AzResourceGroupDeployment `
					-ResourceGroupName $nameResourceGroup `
					-TemplateFile "$PSScriptRoot\CmAzCoreAutomation.json" `
					-WhatIf:$WhatIfPreference `
					-accountName $automationAccountName `
					-location $Location

				function KeyVaultSelfSignedCert {
					param (
						$keyVault,
						$certificateName,
						$subjectName,
						$validityInMonths,
						$renewDaysBefore
					)

					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Starting Certificate Generation..."

					$policy = New-AzKeyVaultCertificatePolicy `
						-SubjectName $subjectName `
						-ReuseKeyOnRenewal `
						-IssuerName 'Self' `
						-ValidityInMonths $validityInMonths `
						-RenewAtNumberOfDaysBeforeExpiry $renewDaysBefore

					$keyVaultCertificate = Add-AzKeyVaultCertificate `
						-VaultName $keyVault `
						-CertificatePolicy $policy `
						-Name $certificateName

					while ( $keyVaultCertificate.Status -ne 'completed' ) {
						Start-Sleep -Seconds 1
						$keyVaultCertificate = Get-AzKeyVaultCertificateOperation -VaultName $keyVault -Name $certificateName
					}

					(Get-AzKeyVaultCertificate -VaultName $keyVault -Name $certificateName).Certificate
				}

				function CreateServicePrincipal {
					param (
						[System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
						[string] $applicationDisplayName
					)

					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Fetch Certificate Data from Keyvault"
					$PfxCert = [Convert]::ToBase64String($Certificate.GetRawCertData())
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Fetch Certificate Data from Keyvault..Done!"
					$Application = New-AzADApplication -DisplayName $applicationDisplayName -HomePage ("http://" + $applicationDisplayName) -IdentifierUris ("http://" + $RandomValue)
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Requires Application administrator or GLOBAL ADMIN"
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Trying to create Application Credential"
					$ApplicationCredential = New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $PfxCert -StartDate $Certificate.NotBefore -EndDate $Certificate.NotAfter
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Trying to create Application Credential..Done!!"
					# Requires Application administrator or GLOBAL ADMIN
					Write-Verbose "Working on creating service principal"
					$ServicePrincipal = New-AzADServicePrincipal -ApplicationId $Application.ApplicationId
					Write-Verbose "Service Principal created !!!"
					$GetServicePrincipal = Get-AzADServicePrincipal -ObjectId $ServicePrincipal.Id
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Application credential: $ApplicationCredential"
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Service principal Id: $GetServicePrincipal"

					Start-Sleep -s 15
					# Requires User Access Administrator or Owner.

					Write-Verbose "((get-date).TimeOfDay.ToString()) - working on getting role assignment"
					$GetRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue

					if (!$GetRole) {

						Write-Verbose "((get-date).TimeOfDay.ToString()) - Role Assignment doesnt exist. Trying to create one"
						$NewRole = New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue

						$Retries = 0;

						While (!$NewRole -and $Retries -le 6) {
							Start-Sleep -s 10
							New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
							$NewRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
							$Retries++;
						}

						Write-Verbose "((get-date).TimeOfDay.ToString()) - Contributer role assigned to service principal $($Application.ApplicationId)"
					}
					else {
						Write-Verbose "$((get-date).TimeOfDay.ToString()) - Role Assignment Already Present..."
						Write-Verbose $GetRole
					}
					return $Application;
				}
				function CreateAutomationCertificateAsset {

					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Trying to Pull Certificate Password from KeyVault"
					$CertificatePassword = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultCertificatePassword).SecretValue

					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Trying to Pull Certificate from KeyVault"
					$pfxFileByte = (Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName).Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $CertificatePassword)
					$PfxCertPathForRunAsAccount = Join-Path  -Path $($ProjectContext.ProjectRoot) ($certificateName + ".pfx")
					# Write to a file
					[System.IO.File]::WriteAllBytes($PfxCertPathForRunAsAccount, $pfxFileByte)

					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Creating Automation Certificate Asset"
					Remove-AzAutomationCertificate -ResourceGroupName $nameResourceGroup -AutomationAccountName  $automationAccountName -Name "AzureRunAsCertificate" -ErrorAction SilentlyContinue
					New-AzAutomationCertificate -ResourceGroupName $nameResourceGroup -AutomationAccountName  $automationAccountName -Path $PfxCertPathForRunAsAccount  -Name "AzureRunAsCertificate" -Password $CertificatePassword
					Write-Verbose "Key Vault Certificate ported to Automation Certificate Asset successfully"
				}
				function CreateAutomationConnectionAsset {
					param (
						[string] $nameResourceGroup,
						[string] $automationAccountName,
						[string] $connectionAssetName,
						[string] $connectionTypeName,
						[System.Collections.Hashtable] $connectionFieldValues
					)
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Creating Automation Connection Asset"
					Remove-AzAutomationConnection -ResourceGroupName $nameResourceGroup -AutomationAccountName  $automationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
					New-AzAutomationConnection -ResourceGroupName $nameResourceGroup -AutomationAccountName  $automationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues
					Write-Verbose "$((get-date).TimeOfDay.ToString())  - Automation connection $ConnectionAssetName' created successfully"
				}

				[string]$ApplicationDisplayName = "AutomationAppAccount-$automationAccountName"
				$SelfSignedCrtMonthstoExpire = 12

				# Mandatory Azure Default Vaules - DO NOT CHANGE
				[string]$ConnectionAssetName = "AzureRunAsConnection"
				[string]$ConnectionTypeName = "AzureServicePrincipal"

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Get Certificate from Keyvault"
				$keyVaultSelfSignedCert = (Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName).Certificate

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Create New Certificate using keyvault If doesnot exist"
				if (!$keyVaultSelfSignedCert) {
					try {
						Write-Verbose "$((get-date).TimeOfDay.ToString()) - Certificate doesnot exist..."
						Write-Verbose "$((get-date).TimeOfDay.ToString()) - Creating new certificate in keyvault: $keyVaultName"
						$keyVaultSelfSignedCert = KeyVaultSelfSignedCert  `
							-keyVault $keyVaultName `
							-certificateName $certificateName `
							-subjectName "CN=$certificateName" `
							-validityInMonths $SelfSignedCrtMonthstoExpire `
							-renewDaysBefore 30
						Write-Verbose "$((get-date).TimeOfDay.ToString()) - Certificate generated $certificateName : $($keyVaultSelfSignedCert.Thumbprint)"
						$keyVaultSelfSignedCert = (Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName).Certificate
					}
					catch {
						Write-Error "$((get-date).TimeOfDay.ToString()) - Certificate Generation failed"
						break
					}
				}
				else {
					Write-Verbose "$((get-date).TimeOfDay.ToString()) - Certificate found $certificateName : $($keyVaultSelfSignedCert.Thumbprint)"
				}

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Create a service principal"
				$servicePrincipal = CreateServicePrincipal -Certificate $keyVaultSelfSignedCert -applicationDisplayName $ApplicationDisplayName

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Populate the ConnectionFieldValues"
				$thumbprint = $keyVaultSelfSignedCert.Thumbprint
				$ConnectionFieldValues = @{"ApplicationId" = $servicePrincipal.ApplicationId.ToString(); "TenantId" = $AzSubscription.TenantId; "CertificateThumbprint" = $thumbprint; "SubscriptionId" = $AzSubscription.SubscriptionId }

				Write-Verbose "$((get-date).TimeOfDay.ToString()) - Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal."
				CreateAutomationCertificateAsset
				CreateAutomationConnectionAsset -nameResourceGroup $nameResourceGroup -automationAccountName $automationAccountName -ConnectionAssetName "AzureRunAsConnection" -connectionTypeName $ConnectionTypeName -connectionFieldValues $ConnectionFieldValues


				try {
					if ($repoUrl) {
						if ($repoType -eq "tvfc") {
							New-AzAutomationSourceControl -Name SCReposTFVC -repoUrl $repoUrl -SourceType VsoTfvc -AccessToken $PersonalAccessToken -ResourceGroupName $nameResourceGroup -AutomationAccountName $automationAccountName -folderPath $folderPath -EnableAutoSync
						}
						elseif ($repoType -eq "github") {
							New-AzAutomationSourceControl -Name GithubSync -repoUrl $repoUrl -SourceType GitHub -AccessToken $PersonalAccessToken -Branch master -ResourceGroupName $nameResourceGroup -AutomationAccountName $automationAccountName -folderPath $folderPath
						}
						elseif ($repoType -eq "git") {
							New-AzAutomationSourceControl -Name GitSync -repoUrl $repoUrl -SourceType VsoGit -AccessToken $PersonalAccessToken -Branch master -ResourceGroupName $nameResourceGroup -AutomationAccountName $automationAccountName -folderPath $folderPath -EnableAutoSync
						}
						else {
							Write-Error "Please choose correct repository - tvfc | git | github" -ErrorAction Continue
						}

						Write-Verbose "$((get-date).TimeOfDay.ToString()) - $repoType Added"
					}

					Write-Verbose "$((get-date).TimeOfDay.ToString()) - $repoType Added"
				}
				catch {
					Write-Verbose "Repository couldn't be added"
					write-Verbose "$($PSitem.ToString)"
				}
			}
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}
}
