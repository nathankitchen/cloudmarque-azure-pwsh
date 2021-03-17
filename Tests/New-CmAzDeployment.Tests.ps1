Describe "New-CmAzDeployment Tests" {

    Context "<_.baseName> configuration" -Foreach (Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project" -Directory -Force) {

        $excludedFiles = @("partners.yml", "recoveryPolicy.yml")
        $settingsFiles = Get-ChildItem -Path $_.pspath -Filter "*.yml" -Exclude $excludedFiles -Depth 0 -Force

        It "should be able to call the correctly associated command for <_.baseName>" -ForEach $settingsFiles {
            
            $deployments = ""

            {
                if ($_.name -eq "virtualmachines.yml") {

                    # Workaround as secure string doesn't work being passed in as params to dynamic invoke-expression calls
                    $username = ConvertTo-SecureString 'testUser' -AsPlainText -Force
                    $password = ConvertTo-SecureString 'testPass' -AsPlainText -Force

                    $deployments = New-CmAzDeployment `
                        -SettingsFile $_.psPath `
                        -LocalAdminUsername $username `
                        -LocalAdminPassword $password `
                        -WhatIf `
                        -Verbose 4>&1
                }
                elseif ($_.name -eq "recoveryvault.yml") {
                    
                    $deployments = New-CmAzDeployment `
                        -SettingsFile $_.psPath `
                        -PolicySettingsFile "$($_.directory)\recoverypolicy.yml" `
                        -WhatIf `
                        -Verbose 4>&1
                }
                else  {
                    
                    $deployments = New-CmAzDeployment `
                        -SettingsFile $_.psPath `
                        -WhatIf `
                        -Verbose 4>&1
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