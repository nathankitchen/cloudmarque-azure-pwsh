function Get-SchemaPath {

    param(
        [parameter(Mandatory = $true)]
        [String]$CmdletName,
        [String]$SubSchema
	)

    if ($SubSchema) {
        $path = "$PSScriptRoot/../../Resources/Schema/Subschema/$SubSchema"
    }
    else {
        $path = "$PSScriptRoot/../../Resources/Schema/$($CmdletName).Schema.json"
    }

    if (!(Test-Path -Path $path -IsValid)) {
        Write-Error "Schema file path is invalid for $CmdletName." -Category InvalidArgument -CategoryTargetName "CmdletName"
    }
    elseif (!(Test-Path -Path $path)) {
        Write-Error "Schema file doesnt exist for $CmdletName." -Category InvalidArgument -CategoryTargetName "CmdletName"
    }

    $path
}