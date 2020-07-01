function Get-CmAzContext {
    <#
   .Synopsis
    Gets the session context.

   .Description
    Gets the current project directory and environment, which are used as context to
    a range of commands that might be executed as part of a deployment. The project
    directory contains naming standards and pipelines to deploy.

   .Component
    Global

   .Parameter RequireAzure
    Throws an exception if no Azure Context is set, prompting the user to sign in
    with Login-AzAccount or similar.

   .Parameter ThrowIfUnavailable
    Throws an exception if the Cloudmarque Azure context is unset or empty, prompting
    the user to call the `Set-CmAzContext` command.

   .Example
    # Retrieve the current Cloudmarque.Azure context
    $ctx = Get-CmAzContext -RequireAzure -ThrowIfUnavailable
  #>

  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="Using a global variable for session state")]
  [CmdletBinding()]
  param(
    [Switch]$RequireAzure,
    [Switch]$ThrowIfUnavailable
  )
  process {

    if ($RequireAzure) {

      $context = Get-AzContext

      if (!$context) {
        throw "You must be logged into Azure. Please ensure you have an AzContext before running this command."
      }
    }

    if ($ThrowIfUnavailable -And (-Not $global:CMAZ_CTX)) {
      throw "No Cloudmarque Azure context is in place, please run Set-CmAzContext before running this command."
    }
    $global:CMAZ_CTX
  }
}