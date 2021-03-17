function Get-Settings() {

    param(
        [String]$SettingsFile,
        [Object]$SettingsObject,
        [parameter(Mandatory = $true)]
        [String]$CmdletName
    )

    if ($SettingsFile -and !$SettingsObject) {
        $SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
    }
    elseif (!$SettingsFile -and !$SettingsObject) {
        Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
    }
    elseif (!$CmdletName) {
        Write-Error "Please provide the a cmdlet name, so the correct validation scshema can be loaded." -Category InvalidArgument -CategoryTargetName "CmdletName"
    }

    $ErrorActionPreference = "Stop"

    $schemaFile = Get-SchemaPath -CmdletName $CmdletName

    $success = Test-Json -Json ($SettingsObject | ConvertTo-Json -Depth 32) -Schema (Get-Content -Path $schemaFile -Raw)

    $SettingsObject
}