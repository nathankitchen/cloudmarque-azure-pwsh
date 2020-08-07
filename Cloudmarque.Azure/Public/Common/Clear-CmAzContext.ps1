function Clear-CmAzContext {

	<#
		.Synopsis
		 Removes the current Cloudmarque Azure context data from the global session.

		.Description
		 Removes the global variables that represent the Cloudmarque.Azure session,
		 preventing further context-dependent commands from executing.

		.Example
		 Clear-CmAzContext
	#>

	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification = "Using a global variable for session state")]
	[CmdletBinding()]
	param()
	
	if ((Test-Path $PROFILE.CurrentUserCurrentHost)) {
		
		[string[]]$nonContextFileContent = Get-Content $PROFILE.CurrentUserCurrentHost
		
		$nonContextFileContent = $nonContextFileContent | Where-Object { !$_.StartsWith("`$global:CMAZ_CTX") }

		if (!$nonContextFileContent) {
			Write-Verbose "Remove profile"
			Remove-Item $PROFILE.CurrentUserCurrentHost
		}
		else {
			Write-Verbose "Reset profile"
			$nonContextFileContent | Out-File $PROFILE.CurrentUserCurrentHost
		}
	}

	if ($global:CMAZ_CTX) {
		Remove-Variable "CMAZ_CTX" -Scope "Global"
	}

	if($env:CMAZ_CTX_ENV) {
		Remove-Item env:CMAZ_CTX_ENV
	}

	Write-Verbose "Cloudmarque.Azure context cleared successfully"
}