function New-CmAzIaasNetSpoke {
    <#
    .SYNOPSIS
    Template Synopsis, to be replaced later.

    .DESCRIPTION
    Template description, to be replaced later.

    .EXAMPLE
    New-CmAzIaasNetSpoke -testSTR Bob -testINT 9

    .COMPONENT
    IaaS
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [string]$testSTR = "",
        [int]$testINT = 0
    )
    if($PSCmdlet.ShouldProcess("Deploy net spoke")) {
        Write-Output $((Get-PsCallStack)[0])
    }
}
