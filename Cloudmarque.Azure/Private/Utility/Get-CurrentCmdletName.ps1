function Get-CurrentCmdletName {
	param(
		[parameter(Mandatory = $true)]
		[String]$ScriptRoot
    )

    (Split-Path -Path $ScriptRoot -Leaf -Resolve).replace('.ps1', '')
}