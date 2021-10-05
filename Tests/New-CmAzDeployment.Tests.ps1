Describe "New-CmAzDeployment Tests" {

    Context "<_.baseName> configuration" -Foreach (Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project" -Directory -Force) {

        $excludedFiles = @("partners.yml", "recoveryPolicy.yml", "services.yml")
        $settingsFiles = Get-ChildItem -Path $_.pspath -Filter "*.yml" -Exclude $excludedFiles -Depth 0 -Force

        It "should be able to call the correctly associated command for <_.baseName>" -ForEach $settingsFiles {

            $deployments = ""

            $name = $_.name
            $path = $_.psPath
            $directory = $_.directory

            {
                $deployments = switch ($name) {

                    "virtualmachines.yml" {

                        $username = ConvertTo-SecureString 'testUser' -AsPlainText -Force
                        $password = ConvertTo-SecureString 'testPass' -AsPlainText -Force

                        New-CmAzDeployment `
                            -SettingsFile $path `
                            -LocalAdminUsername $username `
                            -LocalAdminPassword $password `
                            -WhatIf `
                            -Verbose 4>&1
                    }

                    "recoveryvault.yml" {

                        New-CmAzDeployment `
                            -SettingsFile $path `
                            -PolicySettingsFile "$directory\recoverypolicy.yml" `
                            -WhatIf `
                            -Verbose 4>&1
                    }

                    Default {

                        New-CmAzDeployment `
                            -SettingsFile $path `
                            -WhatIf `
                            -Verbose 4>&1
                    }
                }

                $deployments.toString() | Should -Not -BeNullOrEmpty

            } | Should -Not -Throw
        }
    }

    Context "Cmdlet not identified" {

        It "should throw error message" {
            {
                $SettingsObject = Get-CmAzSettingsFile -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project\Integration\security.yml"
                $SettingsObject.component = ""

                New-CmAzDeployment -SettingsObject $SettingsObject -WhatIf
            }  | Should -Throw "Please provide appropriate component value in settings file or object.."
        }
    }
}