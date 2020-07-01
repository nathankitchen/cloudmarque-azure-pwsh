. $PSScriptRoot\Initialise-CmAzModule.ps1

$projectRoot = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project";
$testProjectRoot = "$PSScriptRoot\TestProject"

Describe "*-CmAzContext Lifecycle Tests" {
  Context "Get-CmAzContext" {
    It "Should fail when no CmAzContext is available and -ThrowIfUnavailable is set" {
      {
        Clear-CmAzContext
        Get-CmAzContext -ThrowIfUnavailable
      } | Should Throw "No Cloudmarque Azure context is in place, please run Set-CmAzContext before running this command."
    }
    It "Should fail when Azure is unavailable and -RequireAzure is set" {
      {
        Clear-AzContext -Force -Scope "Process"
        Set-CmAzContext -ProjectRoot $projectRoot -Environment "Development"
        Get-CmAzContext -ThrowIfUnavailable -RequireAzure
      } | Should Throw "You must be logged into Azure. Please ensure you have an AzContext before running this command."
    }
    It "Should get the current context" {
      Clear-AzContext -Force
      Set-CmAzContext -ProjectRoot $projectRoot -Environment "Development"
      Set-CmAzContext -ProjectRoot $projectRoot -Environment "Test"
      $context = Get-CmAzContext -ThrowIfUnavailable
      $context.Environment | Should -Be "Test"
    }
  }
  Context "Set-CmAzContext" {
    It "Should return the newly configured context" {
      $c1 = Set-CmAzContext -ProjectRoot $projectRoot -Environment "Development"
      $c2 = Set-CmAzContext -ProjectRoot $projectRoot -Environment "Test"
      $c1.Environment | Should -Be "Development"
      $c2.Environment | Should -Be "Test"
    }
    It "Should auto create a project root if confirmation parameter is y" {
      Set-CmAzContext -ProjectRoot $testProjectRoot -Environment "Development" -ProjectConfirmation "y"
      $expectedItems = Get-ChildItem $projectRoot -Recurse -Force
      $actualItems = Get-ChildItem $testProjectRoot -Recurse -Force
      $differences = Compare-Object $expectedItems $actualItems -Property Name, Length
      $differences | should Be $null
    }
  }
  Context "Clear-CmAzContext" {
    It "Should make the current context null" {
      $c1 = Set-CmAzContext -ProjectRoot $projectRoot -Environment "Development"
      Clear-CmAzContext
      $c2 = Get-CmAzContext
      $c1.Environment | Should -Be "Development"
      $c2 | Should -Be $Null
    }
  }
  AfterAll {
    Remove-Item -path $testProjectRoot -Recurse -Force
  }
}