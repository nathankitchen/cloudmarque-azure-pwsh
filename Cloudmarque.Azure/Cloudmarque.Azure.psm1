$includes = @(
    @{ Directory = "Private"; Export = $false },
    @{ Directory = "Public";  Export = $true  }
);

foreach ($includeProps in $includes) {

    $include = New-Object psobject -Property $includeProps;

    if ($include.Export) {
        $items = Get-ChildItem -Path "$PSScriptRoot\$($include.Directory)\" -Filter "*.ps1" -Recurse -Force
        foreach($item in $items)  {
            . $item.FullName
            Export-ModuleMember -Function $item.BaseName
        }
    }
}