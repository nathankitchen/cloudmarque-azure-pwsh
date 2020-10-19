function Resolve-FilePath() {

    param(
        [parameter(Mandatory = $true)]
        [string]$NestedFile
    )

    if ($NestedFile.StartsWith('./')) {
        $NestedFile.replace('./', "$((Get-CmAzContext).ProjectRoot)/")
    }
    elseif ($NestedFile.StartsWith('.\')) {
        $NestedFile.replace('.\', "$((Get-CmAzContext).ProjectRoot)\")
    }
    else {
        $NestedFile
    }
}
