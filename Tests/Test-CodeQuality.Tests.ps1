. $PSScriptRoot\Initialise-CmAzModule.ps1

Describe 'Testing against PSSA rules' {
    Context 'PSSA Standard Rules' {
        $analysis = Invoke-ScriptAnalyzer -Path "filesystem::$PSScriptRoot/../Cloudmarque.Azure" -Recurse

        if(!$analysis) {
            $analysis = @{"Rulename" = "noerror"}
        }

        $scriptAnalyzerRules = Get-ScriptAnalyzerRule

        forEach ($rule in $scriptAnalyzerRules) {
            It "Should pass $rule" {
                If ($analysis.RuleName -contains $rule) {
                    $analysis | Where-Object RuleName -EQ $rule -outvariable failures | Out-Default
                    $failures.Count | Should Be 0
                }
            }
        }
    }
}