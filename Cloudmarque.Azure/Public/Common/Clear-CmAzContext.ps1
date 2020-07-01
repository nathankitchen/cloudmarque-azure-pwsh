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
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="Using a global variable for session state")]
  [CmdletBinding()]
  param()
  process {
    if ($global:CMAZ_CTX) {
      Remove-Variable "CMAZ_CTX" -Scope "Global"
    }

    Write-Verbose "Cloudmarque.Azure context cleared successfully"
  }
}