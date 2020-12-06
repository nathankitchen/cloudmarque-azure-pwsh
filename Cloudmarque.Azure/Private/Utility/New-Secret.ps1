function New-Secret() {
    
	param(
		[parameter(Mandatory = $true)]
        [int]$Count,
        [int]$MinLength = 20
	)

    $secretValues = Get-Password -MinPasswordLength $MinLength -Count $Count

    if ($secretValues -Is [String]) {
        @($secretValues)
    }
    else {
        $secretValues
    }
}