. $PSScriptRoot\Initialise-CmAzModule.ps1

Describe "New-CmAzProject Tests" {
	
	Context "New-CmAzProject" {
		
		BeforeAll {
			$source = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project"
			$destination = "$PSScriptRoot\testFiles"
		}
		
		It "Should Copy files from $source to $destination" {
			
			New-Item -Path $destination -ItemType "directory"

			New-CmAzProject -Project $destination

			$sourceItems = Get-ChildItem $source -Recurse -Force
			$destinationItems = Get-ChildItem $destination -Recurse -Force

			$differences = Compare-Object $sourceItems $destinationItems -Property Name, Length
			$differences | Should -Be $null
		}

		AfterAll {
			Remove-Item -path $destination -Recurse -Force
		}
	}
}