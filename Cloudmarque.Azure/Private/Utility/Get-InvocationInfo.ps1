function Get-InvocationInfo() {

    param(
        [parameter(Mandatory = $true)]
        [string]$CommandName
    )

    Write-Verbose "Invoking $CommandName"
}