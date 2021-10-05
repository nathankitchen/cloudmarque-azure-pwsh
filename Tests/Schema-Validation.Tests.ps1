Describe "Each deployment cmdlet has an associated schema for input settings validation." {

    $deploymentCmdlets = Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Public\Deploy" -Filter "*.ps1" -Recurse -Force
    $deploymentNames = $deploymentCmdlets.baseName | Where-Object { $_ -ne "New-CmAzIaasNetworking" }

    It "<_> should have a associated validation schema" -ForEach $deploymentNames {

        $schema = Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Schema" -Filter "$_.Schema.json"
        $schema | Should -Not -BeNull
    }
}

Describe "Each deployment cmdlet settings file should have a correctly configured setting validation json schema." {

    $projectConfigs = Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project" -Directory -Force

    Context "<_.baseName> configuration" -ForEach $projectConfigs {

        $excludedFiles = @("deleteService.yml", "partners.yml", "recoveryPolicy.yml", "services.yml")
        $settingsFiles = Get-ChildItem -Path $_.pspath -Filter "*.yml" -Exclude $excludedFiles -Depth 0 -Force

        It "<_.name> should pass schema validation." -ForEach $settingsFiles {

            # Workaround as secure string doesn't work being passed in as params to dynamic invoke-expression calls
            $username = ConvertTo-SecureString 'testUser' -AsPlainText -Force
            $password = ConvertTo-SecureString 'testPass' -AsPlainText -Force

            $path = $_.psPath
            $name = $_.name
            $directory = $_.directory

            switch ($name) {

                "virtualmachines.yml" {
                    { New-CmAzDeployment -SettingsFile $path -LocalAdminUsername $username -LocalAdminPassword $password -WhatIf } | Should -Not -Throw
                }

                "recoveryvault.yml" {
                    { New-CmAzDeployment -SettingsFile $path -PolicySettingsFile "$directory\recoverypolicy.yml" -WhatIf } | Should -Not -Throw
                }

                Default {
                    { New-CmAzDeployment -SettingsFile $path -WhatIf } | Should -Not -Throw
                }
            }
        }
    }
}