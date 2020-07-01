function New-CmAzIaasNetHub {
     <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .COMPONENT
    IaaS
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [string]$testSTR = "",
        [int]$testINT = 0
    )

    # https://www.youtube.com/watch?v=s2LoRzkoi9k
    # requires vnet, vnet gateway, public ip
    if($PSCmdlet.ShouldProcess("Deploy net hub")) {
        Write-Output $((Get-PsCallStack)[0])
    }
}
