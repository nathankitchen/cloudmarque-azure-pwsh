Describe "*-CmAzContext Lifecycle Tests" {

	BeforeAll {
		$projectRoot = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project";
		$azureContextFilePath = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project\context.json"

		Save-AzContext -Path $azureContextFilePath -Force

		$cloudmarqueContext = Get-CmAzContext
	}

	Context "Get-CmAzContext" {

		It "Should fail when no CmAzContext is available and -ThrowIfUnavailable is set" {

			{
				Clear-CmAzContext
				Get-CmAzContext -ThrowIfUnavailable

			} | Should -Throw "No Cloudmarque Azure context is in place, please run Set-CmAzContext before running this command."
		}

		It "Should fail when Azure is unavailable and -RequireAzure is set" {

			{
				Clear-AzContext -Force
				Get-CmAzContext -ThrowIfUnavailable -RequireAzure

			} | Should -Throw "You must be logged into Azure. Please ensure you have an AzContext before running this command."
		}

		It "Should get the most up to date context" {

			$environment = "Test"

			Set-CmAzContext -ProjectRoot $projectRoot -Environment "Development"
			Set-CmAzContext -ProjectRoot $projectRoot -Environment $environment

			$context = Get-CmAzContext -ThrowIfUnavailable
			$context.Environment | Should -Be $environment
		}
	}

	Context "Set-CmAzContext" {

		It "Should return the newly configured context" {

			$devEnvironment = "Development"
			$testEnvironment = "Test"

			$c1 = Set-CmAzContext -ProjectRoot $projectRoot -Environment $devEnvironment
			$c2 = Set-CmAzContext -ProjectRoot $projectRoot -Environment $testEnvironment

			$c1.Environment | Should -Be $devEnvironment
			$c2.Environment | Should -Be $testEnvironment
		}

		It "Should auto create a project root if confirmation parameter is y" {

			$testProjectRoot = "$PSScriptRoot\TestProject"

			Set-CmAzContext -ProjectRoot $testProjectRoot -Environment "Development" -ProjectConfirmation "y"

			$expectedItems = Get-ChildItem $projectRoot -Recurse -Force
			$actualItems = Get-ChildItem $testProjectRoot -Recurse -Force

			$differences = Compare-Object $expectedItems $actualItems -Property Name, Length
			$differences | Should -Be $null

			Remove-Item -path $testProjectRoot -Recurse -Force
		}
	}

	Context "Clear-CmAzContext" {

		BeforeAll {
			Set-CmAzContext -ProjectRoot $projectRoot -Environment "Development"
			Clear-CmAzContext
		}

		It "Should remove the current context" {
			Get-CmAzContext | Should -Be $Null
		}

		It "Should clear profile on clearing CmAzContext" {
			$filecontent = (Get-Content $PROFILE.CurrentUserCurrentHost -Erroraction SilentlyContinue) | Should -Be $Null
		}
	}

	AfterAll {

		Import-AzContext -Path $azureContextFilePath
		Remove-Item -Path $azureContextFilePath -ErrorAction SilentlyContinue -Force

		if($cloudmarqueContext) {
			Set-CmAzContext -Environment $cloudmarqueContext.environment -ProjectRoot $cloudmarqueContext.projectRoot -BuildId $cloudmarqueContext.buildId
		}
		else {
			Clear-CmAzContext
		}
	}
}