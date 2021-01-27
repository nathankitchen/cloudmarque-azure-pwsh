Sync-CloudmarqueAzure

$excludes = @("generators.yml", "naming.yaml")
$resourceFiles = Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project" -Recurse -Force -Exclude $excludes -File | Select-String "component" -List | Select-Object Filename, Path
$errorMessage = "Please provide appropriate component value in settings file or object.."

Describe "New-CmAzDeployment Tests" {

    Context "Cmdlet is successfully identified" {

        It "should be able to call the correctly associated command for <_.Filename>" -TestCases $resourceFiles {
            {
                $deployments = ""

                if ($_.Filename -eq "virtualmachines.yml") {

                    $username = ConvertTo-SecureString -String "testuser" -AsPlainText -Force
                    $password = ConvertTo-SecureString -String (Get-Password -MinPasswordLength 20) -AsPlainText -Force

                    $deployments = New-CmAzDeployment -SettingsFile $_.Path -LocalAdminUsername $username -LocalAdminPassword $password -WhatIf -Verbose 4>&1 -Erroraction continue
                }
                else {
                    $deployments = New-CmAzDeployment -SettingsFile $_.Path -WhatIf -Verbose 4>&1 -Erroraction continue
                }

                $deployments.toString() | Should -Not -BeNull

            } | Should -Not -Throw $errorMessage
        }
    }

    Context "Cmdlet not identified" {

        It "should throw error message" {
            {
                New-CmAzDeployment -SettingsFile "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project\security.yml" -WhatIf
            }  | Should -Throw $errorMessage
        }
    }
}