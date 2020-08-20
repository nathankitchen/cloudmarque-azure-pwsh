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
			* Optionally sync code repository (tvfc | git | github).

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

	$ErrorActionPreference = "Stop"

	try {

		if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy Cloudmarque Core Automation Stack")) {

			# Initializing settings file values

			$azSubscription = Get-AzSubscription
			$projectContext = Get-CmAzContext -RequireAzure -ThrowIfUnavailable

			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

			foreach ($item in $SettingsObject.Automation.Keys) {

				$randomValue = Get-Random -Minimum 1001 -Maximum 9999

				# Set Account Type
				if ($item -eq "dsc") {
					$accountType = "dsc"
				}
				elseif ($item -eq "runbook") {
					$accountType = "runbook"
				}
				else {
					Write-Error "Set type to be either runbook or dsc"
					Break
				}

				$location = $SettingsObject.Location
				Write-Verbose "Location set to $location"
				Write-Verbose "creating automation account for $accountType"
				if (!$location) {
					Write-Error "Location not found"
					Break
				}

				$keyVaultName = $SettingsObject.Automation.$accountType.KeyVaultName
				if (!$keyVaultName) {
					Write-Error "Provide Key Vault For Certificate"
					break
				}

				$keyVault = Get-AzKeyVault -VaultName $keyVaultName

				if (!$keyVault) {
					Write-Error "Key Vault $keyVaultName doesnt exist. Please provide existing Key Vault Name"
					Break
				}

				$certificateName = $SettingsObject.Automation.$accountType.CertificateName
				if (!$certificateName) {
					Write-Information "No KeyVault Certificate Provided.. A new certificate will be created"
					$certificateName = $SettingsObject.Automation.$accountType.CertificateName
				}
				$keyVaultCertificatePassword = $SettingsObject.Automation.$accountType.KeyVaultCertificatePassword
				if (!$keyVaultCertificatePassword) {
					Write-Error "No keyVault path or Password provided for Certificate...."
					break
				}

				if ($SettingsObject.Automation.$accountType.sourceControl.url) {

					$repoUrl = $SettingsObject.Automation.$accountType.sourceControl.url
					$repoType = $SettingsObject.Automation.$accountType.sourceControl.type
					$folderPath = $SettingsObject.Automation.$accountType.sourceControl.folderPath
					$keyVaultPersonalAccessToken = $SettingsObject.Automation.$accountType.sourceControl.keyVaultPersonalAccessToken
					$branch = $SettingsObject.Automation.$accountType.sourceControl.branch

					if (!$keyVaultPersonalAccessToken) {
						Write-Error "No keyVault path or Password provided for Personal Access Token...."
						break
					}
					if (!$branch) {
						$branch = "master"
					}
					if (!$repoType) {
						$repoType = "github"
					}
					$repoType = $repoType.ToLower()
					if (!$folderPath) {
						$folderPath = "/"
					}

					$personalAccessToken = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultPersonalAccessToken).SecretValue
					if (!$personalAccessToken) {
						Write-Error "No PAT found on key vault"
					}
					Write-Verbose "Repository settings are found to be ok. SCM integration will be attempted."
				}
				else {
					Write-Verbose "No Repository provided $accountType"
					Write-Verbose "SCM Intergration will be skipped ... "
				}


				$nameResourceGroup = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region $location -Name $SettingsObject.name
				$resourceGroup = New-AzResourceGroup -ResourceGroupName $nameResourceGroup -Location $location -Force
				Write-Verbose "Resource Group Created : $nameResourceGroup"

				# Creating Automation accountname using name generator
				$automationAccountName = Get-CmAzResourceName -Resource "Automation" -Architecture "Core" -Region $location -Name $SettingsObject.name

				# Create Automation account
				New-AzResourceGroupDeployment `
					-ResourceGroupName $nameResourceGroup `
					-TemplateFile "$PSScriptRoot\New-CmAzCoreAutomation.json" `
					-AccountName $automationAccountName `
					-Location $location `
					-Force

				function KeyVaultSelfSignedCert {
					param (
						$keyVault,
						$CertificateName,
						$SubjectName,
						$ValidityInMonths,
						$RenewDaysBefore
					)

					Write-Verbose "Starting Certificate Generation..."

					$policy = New-AzKeyVaultCertificatePolicy `
						-SubjectName $SubjectName `
						-ReuseKeyOnRenewal `
						-IssuerName 'Self' `
						-ValidityInMonths $ValidityInMonths `
						-RenewAtNumberOfDaysBeforeExpiry $RenewDaysBefore

					$keyVaultCertificate = Add-AzKeyVaultCertificate `
						-VaultName $keyVault `
						-CertificatePolicy $policy `
						-Name $CertificateName

					while ( $keyVaultCertificate.Status -ne 'completed' ) {
						Start-Sleep -Seconds 1
						$keyVaultCertificate = Get-AzKeyVaultCertificateOperation -VaultName $keyVault -Name $CertificateName
					}
					(Get-AzKeyVaultCertificate -VaultName $keyVault -Name $CertificateName).Certificate
				}

				function CreateServicePrincipal {
					param (
						[System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
						[string] $applicationDisplayName
					)
					Write-Verbose "Fetch Certificate Data from Keyvault"
					$pfxCert = [Convert]::ToBase64String($Certificate.GetRawCertData())
					Write-Verbose "Fetch Certificate Data from Keyvault..Done!"
					$application = Get-AzADApplication -DisplayName $applicationDisplayName -ErrorAction SilentlyContinue
					if (!$application)	{
						Write-Verbose "Application not found. Creating new application.."
						$application = New-AzADApplication -DisplayName $applicationDisplayName -HomePage ("http://" + $applicationDisplayName) -IdentifierUris ("http://" + $randomValue)
					}
					Write-Verbose "Requires Application administrator or GLOBAL ADMIN"
					Write-Verbose "Trying to create Application Credential"
					New-AzADAppCredential -ApplicationId $application.ApplicationId -CertValue $pfxCert -StartDate $Certificate.NotBefore -EndDate $Certificate.NotAfter
					Write-Verbose "Application credential is created."
					# Requires Application administrator or GLOBAL ADMIN
					Write-Verbose "Checking for service principal"
					$servicePrincipal = Get-AzADServicePrincipal -ApplicationId $application.ApplicationId
					if(!$servicePrincipal)	{
						while (!$servicePrincipal)	{
							Write-Verbose "Trying to create new service principal.."
							New-AzADServicePrincipal -ApplicationId $application.ApplicationId
							$servicePrincipal = Get-AzADServicePrincipal -ApplicationId $application.ApplicationId
						}
						Write-Verbose "Service principal created."
					}
					else {
						Write-Verbose "Service principal found."
					}
					# Requires User Access Administrator or Owner.
					Write-Verbose "working on getting role assignment"
					$getRole = Get-AzRoleAssignment -ServicePrincipalName $application.ApplicationId -ErrorAction SilentlyContinue
					if (!$getRole) {
						Write-Verbose "Role Assignment doesnt exist. Trying to create one"
						$newRole = New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $application.ApplicationId -ErrorAction SilentlyContinue

						$retries = 0;

						While (!$newRole -and $retries -le 6) {
							Start-Sleep -s 10
							New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
							$newRole = Get-AzRoleAssignment -ServicePrincipalName $application.ApplicationId -ErrorAction SilentlyContinue
							$retries++;
						}

						Write-Verbose "Contributer role assigned to service principal $($application.ApplicationId)"
					}
					else {
						Write-Verbose "Role Assignment Already Present..."
						Write-Verbose $getRole
					}

					return $application;
				}
				function CreateAutomationCertificateAsset {
					param (
						$certificateName
					)
					Write-Verbose "Trying to Pull Certificate Password from KeyVault"
					$certificatePassword = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultCertificatePassword

					Write-Verbose "Trying to Pull Certificate from KeyVault"
					$pfxFileByte = [System.Convert]::FromBase64String((Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $certificateName).SecretValueText)
					$pfxCertPathForRunAsAccount = Join-Path  -Path $($projectContext.ProjectRoot) ($CertificateName + ".pfx")

					# Write to a file
					$certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
					$certCollection.Import($pfxFileByte, "", [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

					#Export  the .pfx file
					$protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $certificatePassword.SecretValueText)
					[System.IO.File]::WriteAllBytes($PfxCertPathForRunAsAccount, $protectedCertificateBytes)

					Write-Verbose "Creating Automation Certificate Asset"

					Remove-AzAutomationCertificate -ResourceGroupName $nameResourceGroup -AutomationAccountName  $automationAccountName -Name "AzureRunAsCertificate" -ErrorAction SilentlyContinue
					New-AzAutomationCertificate -ResourceGroupName $nameResourceGroup -AutomationAccountName  $automationAccountName -Path $pfxCertPathForRunAsAccount  -Name "AzureRunAsCertificate" -Password $certificatePassword.SecretValue -Exportable
					Write-Verbose "Key Vault Certificate ported to Automation Certificate Asset successfully"

					$certificateVaulesOutput = @{
						"certificatePath" = $PfxCertPathForRunAsAccount;
						"password"        = $certificatePassword.SecretValueText
					}
					$certificateVaulesOutput
				}
				function CreateAutomationConnectionAsset {
					param (
						[string] $ResourceGroup,
						[string] $AutomationAccountName,
						[string] $ConnectionAssetName,
						[string] $ConnectionTypeName,
						[System.Collections.Hashtable] $ConnectionFieldValues
					)
					Write-Verbose "Creating Automation Connection Asset"
					Remove-AzAutomationConnection -ResourceGroupName $ResourceGroup -AutomationAccountName  $AutomationAccountName -Name $ConnectionAssetName -Force -ErrorAction SilentlyContinue
					New-AzAutomationConnection -ResourceGroupName $ResourceGroup -AutomationAccountName  $AutomationAccountName -Name $ConnectionAssetName -ConnectionTypeName $ConnectionTypeName -ConnectionFieldValues $ConnectionFieldValues
					Write-Verbose "Automation connection $ConnectionAssetName created successfully"
				}

				[string]$applicationDisplayName = "AutomationAppAccount-$automationAccountName"

				# Mandatory Azure Default Vaules - DO NOT CHANGE
				[string]$connectionAssetName = "AzureRunAsConnection"
				[string]$connectionTypeName = "AzureServicePrincipal"

				Write-Verbose "Get Certificate from Keyvault"
				$keyVaultSelfSignedCert = (Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName).Certificate

				Write-Verbose "Create New Certificate using keyvault If doesnot exist"
				if (!$keyVaultSelfSignedCert) {
					try {
						Write-Verbose "Certificate doesnot exist..."
						Write-Verbose "Creating new certificate in keyvault: $keyVaultName"
						$keyVaultSelfSignedCert = KeyVaultSelfSignedCert  `
							-KeyVault $keyVaultName `
							-CertificateName $certificateName `
							-SubjectName "CN=$certificateName" `
							-ValidityInMonths 12 `
							-RenewDaysBefore 30
						Write-Verbose "Certificate generated $certificateName : $($keyVaultSelfSignedCert.Thumbprint)"
						$keyVaultSelfSignedCert = (Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName).Certificate
					}
					catch {
						Write-Error "Certificate Generation failed"
						break
					}
				}
				else {
					Write-Verbose "Certificate found $certificateName : $($keyVaultSelfSignedCert.Thumbprint)"
				}

				# creates automation certificate

				$certificateValues = CreateAutomationCertificateAsset -CertificateName $certificateName
				$keyVaultSelfSignedPfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($certificateValues.certificatePath , $certificateValues.password)

				Write-Verbose "Create a service principal"
				$servicePrincipal = CreateServicePrincipal -Certificate $keyVaultSelfSignedPfxCert -ApplicationDisplayName $applicationDisplayName

				Write-Verbose "Populate the ConnectionFieldValues"
				$thumbprint = $keyVaultSelfSignedPfxCert.Thumbprint
				$connectionFieldValues = @{"ApplicationId" = $servicePrincipal.ApplicationId.ToString(); "TenantId" = $azSubscription.TenantId; "CertificateThumbprint" = $thumbprint; "SubscriptionId" = $azSubscription.SubscriptionId }

				Write-Verbose "Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal."
				CreateAutomationConnectionAsset -ResourceGroup $nameResourceGroup -AutomationAccountName $automationAccountName -ConnectionAssetName "AzureRunAsConnection" -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues

				if ($repoUrl) {
					try {
						if ($repoType -eq "tvfc") {
							New-AzAutomationSourceControl -Name "$repoType-$randomValue" -RepoUrl $repoUrl -SourceType VsoTfvc -AccessToken $personalAccessToken -ResourceGroupName $nameResourceGroup -AutomationAccountName $automationAccountName -FolderPath $folderPath
						}
						elseif ($repoType -eq "github") {
							New-AzAutomationSourceControl -Name "$repoType-$randomValue" -RepoUrl $repoUrl -SourceType GitHub -AccessToken $personalAccessToken -Branch $branch -ResourceGroupName $nameResourceGroup -AutomationAccountName $automationAccountName -FolderPath $folderPath
						}
						elseif ($repoType -eq "git") {
							New-AzAutomationSourceControl -Name "$repoType-$randomValue" -RepoUrl $repoUrl -SourceType VsoGit -AccessToken $personalAccessToken -Branch $branch -ResourceGroupName $nameResourceGroup -AutomationAccountName $automationAccountName -FolderPath $folderPath
						}
						else {
							Write-Warning "Please choose correct repository - tvfc | git | github" -ErrorAction Continue
						}
						Write-Verbose "$repoType Added"

						# Attempt autosync
						try {
							Update-AzAutomationSourceControl -AutomationAccountName $automationAccountName -Name "$repoType-$randomValue" -AutoSync $true -ResourceGroupName $nameResourceGroup
						}
						catch {
							$_.ToString() | Write-Verbose
							Write-Warning "AutoSync couldn't be enabled. Make sure you have 'Read, query, manage' permissions" -ErrorAction Continue -WarningAction Continue
						}

						# Start first sync job
						Start-AzAutomationSourceControlSyncJob -AutomationAccountName $automationAccountName -Name "$repoType-$randomValue"  -ResourceGroupName $nameResourceGroup
						Write-Verbose "First Sync initiated."
					}
					catch {
						Write-Verbose "Repository couldn't be added"
						Write-Verbose "$($PSitem.ToString)"
					}
				}
				Write-Verbose "Finished!"
			}
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($PSitem);
	}
}
