Describe "Testing all public cmdLets are documented" {

    $commands = Get-Command -Module "Cloudmarque.Azure"

    forEach ($command in $commands) {

        $commandName = $command.Name

        Context "$($commandName)" {
            
            $help = Get-Help -Name $commandName -Full
            $testCase = @( @{ name = $commandName; docs = $help } )
            $paramCase = @()

            foreach ($parameter in $help.parameters.parameter) {
                
                if ($parameter.name) {
                    $paramCase += @{ command = $commandName; name = $parameter.name; docs = $parameter }
                }
                
            }
            
            It "Should be documented" -TestCases $testCase {
                param($name, $docs)
                $docs | Should -Not -BeNull
            }
        
            It "Should have a synopsis"  -TestCases $testCase {
                param($name, $docs)
                $docs.synopsis | Should -Not -BeNullOrEmpty
            }

            It "Should have a description" -TestCases $testCase {
                param($name, $docs)
                $docs.description | Should -Not -BeNull
                $docs.description.Text | Should -Not -BeNullOrEmpty
            }

            It "Should have a valid component" -TestCases $testCase {
                param($name, $docs)
                $docs.component | Should -BeIn @('Common','Core','IaaS','PaaS','Endpoints','Security','DevOps')
            }

            It "<command> -<name> should have documentation" -TestCases $paramCase {
                param($command, $name, $docs)
                if ($name) {
                    if (-Not ($name -eq "Confirm" -Or $name -eq "WhatIf")) {
                        $docs.description.Text | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
    }
}