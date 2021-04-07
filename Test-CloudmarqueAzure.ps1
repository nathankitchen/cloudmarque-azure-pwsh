function Test-CloudmarqueAzure {

    <#
        .Synopsis
         Runs Pester tests over the Cloudmarque.Azure module, publishing test results.

        .Description
         Supports the development lifecycle by running defined tests to check whether
         commands are behaving as expected. Checks that all modules are in place before
         running them.

        .Example
         Test-CloudmarqueAzure
    #>

    [CmdletBinding()]
    param(
        [ValidateSet("Auto", "AllUsers", "CurrentUser")]
        [String]
        $Scope = "Auto"
    )

    Process {

        $modules =  @(
            @{ ModuleName = "Pester"; RequiredVersion = "5.1.1" },
            @{ ModuleName = "PSScriptAnalyzer"; RequiredVersion = "1.19.1" }
        );

        .$PSScriptRoot/Cloudmarque.Azure/Install-Dependencies.ps1 -AdditionalModules $modules -Scope $Scope -ImportModules $true -Verbose

        Sync-CloudmarqueAzure

        $publishPath = "$PSScriptRoot\Publish"
        $testDirectory = "Tests"
        $testPath = "$publishPath\$testDirectory"

        New-Item -Path $publishPath -Name $Project -ItemType Directory -Force > $Null
        New-Item -Path $testPath -Name $Project -ItemType Directory -Force > $Null

        Import-Module Pester

        $configuration = [PesterConfiguration]@{

            Output = @{
                Verbosity = "Detailed"
            }
            Run = @{
                Path = ".\$testDirectory\*"
            }
            Should = @{
                ErrorAction = "Stop"
            }
            TestResult = @{
                Enabled = $true
                OutputPath = "$testPath\nunit-results.xml"
            }
        }

        Invoke-Pester -Configuration $configuration
    }
}