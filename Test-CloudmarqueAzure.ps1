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
        [ValidateSet("Auto","AllUsers","CurrentUser")]
        [String]
        $Scope = "Auto"
    )
    Process {

        $modules =  @(
            @{ Name = "Pester"; Version = "4.10.1" },
            @{ Name = "PSScriptAnalyzer"; Version = "1.18.3" }
        );

        . ./Install-Dependencies.ps1

        Install-Dependencies -AdditionalModules $modules -Scope $Scope -Verbose

        New-Item -Path "$PSScriptRoot\publish\" -Name $Project -ItemType Directory -Force | Out-Null
        New-Item -Path "$PSScriptRoot\publish\tests\" -Name $Project -ItemType Directory -Force | Out-Null

        Invoke-Pester -Script ".\Tests\*" -OutputFile "$PSScriptRoot\publish\tests\nunit-results.xml" -OutputFormat 'NUnitXML'
    }
}