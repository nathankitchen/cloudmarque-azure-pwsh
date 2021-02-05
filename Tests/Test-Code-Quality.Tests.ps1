Describe 'Testing against PSSA rules' {

    BeforeAll {
        $analysis = Invoke-ScriptAnalyzer -Path "filesystem::$PSScriptRoot/../Cloudmarque.Azure" -Recurse

        if(!$analysis) {
            $analysis = @{"Rulename" = "noerror"}
        }
    }

    Context 'PSSA Standard Rules' {

        forEach ($rule in Get-ScriptAnalyzerRule) {

            It "Should pass $rule" {

                If ($analysis.RuleName -Contains $rule) {
                    $analysis | Where-Object RuleName -EQ $rule -OutVariable Failures | Out-Default
                    $failures.Count | Should -Be 0
                }
            }
        }
    }
}