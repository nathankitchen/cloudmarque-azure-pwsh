function Write-CommandStatus {

    param(
        [parameter(Mandatory = $true)]
        [string]$CommandName,
        [boolean]$Start = $true
    )

    if ($Start) {
        Write-Verbose "Invoking $CommandName"
    }
    else {
        Write-Verbose "Finished $CommandName!"
    }
}