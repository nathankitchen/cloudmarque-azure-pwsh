function Set-CmAzContext {
  <#
    .Synopsis
    Sets the session context for subsequent session runs.

    .Description
    Creates a new directory containing a sample environment for deployment.

    .Example
    # Return a message
    New-CmAzProject -Project "MyProject"
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="Using a global variable for session state")]
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
  param(
        [string]$Environment = "Development",
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot,
        [string]$ProjectConfirmation = "n",
        [string]$BuildId = "001"
  )

  process {

    try {

      if ($PSCmdlet.ShouldProcess("Environment:$Environment", "Set the session context")) {

        $isValid = Test-Path -LiteralPath $ProjectRoot -IsValid

        if (!$isValid) {
          throw "Project root $ProjectRoot is not valid"
        }

        $exists = Test-Path -LiteralPath $ProjectRoot

        if (!$exists -and $ProjectConfirmation -eq "n") {
          $ProjectConfirmation = Read-Host -Prompt "Create new project root? [y/n] (Default: y)"
        }

        if ($ProjectConfirmation -eq "y") {
          New-CmAzProject -Project $ProjectRoot
        }

        $namingFile = "$ProjectRoot/_names/tokens.yml"
        $namingConventions = Get-CmAzSettingsFile -Path $namingFile

        if (!$namingConventions.environments[$Environment.ToLower()]) {
          throw "Environment does not exist!"
        }

        if($CMAZ_CTX){
          Clear-CmAzContext
        }

        $global:CMAZ_CTX = New-Object PSObject -Property  @{Environment = $Environment; ProjectRoot = $ProjectRoot; BuildId= $BuildId};
        $global:CMAZ_CTX

        if(!$(test-path $PROFILE.CurrentUserCurrentHost)){
          new-item $PROFILE.CurrentUserCurrentHost -ItemType file -Force
        }
        Add-Content -Path $Profile.CurrentUserCurrentHost -value "`$global:CMAZ_CTX = New-Object PSObject -Property  @{Environment = `"$Environment`"; ProjectRoot = `"$ProjectRoot`"; BuildId= `"$BuildId`"}"
      }
    }
    catch {
      $PSCmdlet.ThrowTerminatingError($PSitem);
    }
  }
}