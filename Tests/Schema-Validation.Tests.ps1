function Get-DeploymentNames() {
    $deploymentCmdlets = Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Public\Deploy" -Filter "*.ps1" -Exclude "networking" -Recurse -Force

    $deploymentCmdlets.baseName | Where-Object { $_ -ne "New-CmAzIaasNetworking" -and $_ -ne "New-CmAzDeployment" }
}

function Get-CmdletDetails {
    
    @{
        "automation.yml" = "New-CmAzCoreAutomation";
        "bastionhost.yml" = "New-CmAzIaasBastionHost";
        "budgets.yml" = "New-CmAzCoreBillingRule";
        "core.yml" = "New-CmAzCore";
        "deleteservice.yml" = "Set-CmAzCoreAutomationDeleteResource";
        "keyvaults.yml" = "New-CmAzCoreKeyvault";
        "monitor.yml" = "New-CmAzCoreMonitor";
        "recoveryVault.yml" = "New-CmAzIaasRecoveryServicesVault";
        "security.yml" = "Set-CmAzSecurityCentre";
        "sharedImageGallery.yml" = "New-CmAzPaasSharedImageGallery";
        "sql.yml" = "New-CmAzPaasSql";
        "storage.yml" = "New-CmAzIaasStorage";
        "tags.yml" = "Set-CmAzTag"
        "updateManagement.yml" = "Set-CmAzIaasUpdateManagement";
        "virtualmachines.yml" = "New-CmAzIaasVm";
        "vpngw.yml" = "New-CmAzIaasVpnGw";
        "web.yml" = "New-CmAzPaasWeb";
        "webstatic.yml" = "New-CmAzPaasWebStatic";
        "wvd.yml" = "New-CmAzIaasWVD";
    }.GetEnumerator()
}

Describe "Each deployment cmdlet has an associated schema for input settings validation." {

    It "<_> should have a associated validation schema" -Foreach (Get-DeploymentNames) {

        $schema = Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Schema" -Filter "$_.Schema.json"
        $schema | Should -Not -BeNull
    }  
}

Describe "Each deployment cmdlet settings file should have a correctly configured setting validation json schema." {

    It "<_.name> should pass schema validation." -ForEach (Get-CmdletDetails) {

        $settingsFilePath = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project"

        if ($_.name -eq "virtualmachines.yml") {

            # Workaround as secure string doesn't work being passed in as params to dynamic invoke-expression calls
            $username = ConvertTo-SecureString 'testUser' -AsPlainText -Force
            $password = ConvertTo-SecureString 'testPass' -AsPlainText -Force

            {
                New-CmAzIaasVM -SettingsFile "$settingsFilePath/virtualmachines.yml" -LocalAdminUsername $username -LocalAdminPassword $password -WhatIf
            } | Should -Not -Throw
        }
        else {

            $deployExpression = "$($_.value) -SettingsFile $settingsFilePath\$($_.name)"

            if ($_.name -eq "recoveryvault.yml") {
                $deployExpression += " -PolicySettingsFile $settingsFilePath\recoverypolicy.yml"
            }

            $deployExpression += " -WhatIf"

            { Invoke-Expression $deployExpression } | Should -Not -Throw
        }   
    }  
}