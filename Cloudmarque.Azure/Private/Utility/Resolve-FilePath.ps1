function Resolve-FilePath {

    param(
        [parameter(Mandatory = $true)]
        [string]$NestedFile
    )

    if ([System.IO.Path]::IsPathRooted($NestedFile)) {

        return $NestedFile
    }
    else {

        $NestedFile = $NestedFile.replace('./', "$((Get-CmAzContext).ProjectRoot)/")
        $NestedFile = $NestedFile.replace('.\', "$((Get-CmAzContext).ProjectRoot)\")

        return $NestedFile
    }
}
