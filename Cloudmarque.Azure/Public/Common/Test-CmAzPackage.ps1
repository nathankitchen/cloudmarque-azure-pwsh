function Test-CmAzPackage {

	<#
		.Synopsis
		 Validates that the Cloudmarque.Azure package has been correctly installed.

		.Description
		 Returns a message, validating that the package has been correctly installed.

		.Example
		 Test-CmAzPackage
	#>

	[CmdletBinding()]
	[OutputType([System.String])]
	param()

	return "Hello, world!"
}