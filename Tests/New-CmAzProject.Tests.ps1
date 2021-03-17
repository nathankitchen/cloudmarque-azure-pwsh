Describe "New-CmAzProject Tests" {
	
	BeforeAll {
		$source = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project\Integration"
		$destination = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project\UnitTest"
	}

	It "should Copy files from set source to expected destination." {

		New-CmAzProject -Project $destination

		$sourceItems = Get-ChildItem $source -Recurse -Force
		$destinationItems = Get-ChildItem $destination -Recurse -Force

		$differences = Compare-Object $sourceItems $destinationItems -Property Name, Length
		$differences | Should -Be $null
	}

	It "should list all available projects" {

		$actualProjectConfigs = (Get-ChildItem -Path "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project" -Directory -Force).baseName
		$expectedProjectConfigs = New-CmAzProject -ListAvailable

		$differences = Compare-Object $expectedProjectConfigs $actualProjectConfigs -Property Name, Length
		$differences | Should -Be $null
	}

	It "throws an error when a config is not found" {
		{
			New-CmAzProject -ConfigName "NotFound" -Project $destination
		} | Should -Throw "Project configuration not found."
	}

	AfterAll {
		Remove-Item -path $destination -Recurse -Force
	}
}