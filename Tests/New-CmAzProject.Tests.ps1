. $PSScriptRoot\Initialise-CmAzModule.ps1

$source = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project"
$destination = "$PSScriptRoot\testFiles"

Describe "New-CmAzProject Tests" {
  Context "New-CmAzProject" {
    It "Should Copy files from $source to $destination" {

      New-Item -Path $destination -ItemType "directory"

      New-CmAzProject -Project $destination
  
      $sourceItems = Get-ChildItem $source -Recurse -Force
      $destinationItems = Get-ChildItem $destination -Recurse -Force

      $differences = Compare-Object $sourceItems $destinationItems -Property Name, Length
      $differences | should Be $null
    }
  }
  AfterAll {
    Remove-Item -path $destination -Recurse -Force
  }
}