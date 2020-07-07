function Clear-CmAzContext {

	<#
		.Synopsis
		 Removes the current Cloudmarque Azure context data from the global session.

		.Description
		 Removes the global variables that represent the Cloudmarque.Azure session,
		 preventing further context-dependent commands from executing.

   .Example
	# Clear the current Cloudmarque.Azure context
	Clear-CmAzContext
  #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification = "Using a global variable for session state")]
	[CmdletBinding()]
	param()
	process {
		if ($(test-path $PROFILE.CurrentUserCurrentHost)) {
			$value = "`$global:CMAZ_CTX = New-Object PSObject -Property  @{Environment = `"$($CMAZ_CTX.Environment)`"; ProjectRoot = `"$($CMAZ_CTX.ProjectRoot)`"; BuildId= `"$($CMAZ_CTX.BuildId)`"}"
			$filecontent = (Get-content $PROFILE.CurrentUserCurrentHost) -notlike $value

			if ($filecontent -eq "False" -or !$filecontent) {
				Remove-Item $PROFILE.CurrentUserCurrentHost
				Write-Verbose "Remove profile"
			}
			else {
				$filecontent | Out-File $PROFILE.CurrentUserCurrentHost
				Write-Verbose "Reset profile"
			}
		}
		if ($global:CMAZ_CTX) {
			Remove-Variable "CMAZ_CTX" -Scope "Global"
		}
		if($env:CMAZ_CTX_ENV){
			$env:CMAZ_CTX_ENV = $null
		}
		Write-Verbose "Cloudmarque.Azure context cleared successfully"
	}
}