<#
    .Synopsis
     Installs dependencies in order to use Cloudmarque.Azure
    .Example
     . ./Install-Dependencies.ps1
     . ./Install-Dependencies.ps1 -Scope "Manual" -ImportModules $true
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "")]
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
param(
    [Array]
    $AdditionalModules,
    [ValidateSet("Auto", "AllUsers", "CurrentUser")]
    [String]
    $Scope = "Auto",
    [bool]
    $ImportModules = $false
)

$modules = (Import-PowerShellDataFile "$PSScriptRoot/Cloudmarque.Azure.psd1").RequiredModules

if ($additionalModules -and $additionalModules.Count -gt 0) {
    $modules += $AdditionalModules
}

$resolvedScope = "CurrentUser"

if ($IsWindows) {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
    $resolvedScope = if ($Scope -Eq "Auto") { if ($isAdmin) { "AllUsers" } else { "CurrentUser" } } else { $Scope }
}

foreach ($moduleProps in $modules) {

    $module = New-Object psobject -Property $moduleProps;

    Write-Verbose "Looking for $($module.ModuleName) version $($module.RequiredVersion)..."

    if (!(Get-Module -Name $module.ModuleName | Where-Object { ($_.Version -Join ".") -Eq $module.RequiredVersion })) {

        Write-Verbose "Not imported, checking whether it's installed..."

        if (!(Get-Module -ListAvailable -Name $module.ModuleName | Where-Object { ($_.Version -Join ".") -Eq $module.RequiredVersion })) {
            Write-Verbose "Installing $($module.ModuleName) for $resolvedScope..."
            Install-Module -Name $module.ModuleName -RequiredVersion $module.RequiredVersion -Scope $resolvedScope -Force -AllowClobber -SkipPublisherCheck
        }

        if ($ImportModules) {
            Write-Verbose "Importing $($module.ModuleName) version $($module.RequiredVersion)..."
            Import-Module -Name $module.ModuleName -RequiredVersion $module.RequiredVersion -Force
        }
    }
    else {
        Write-Verbose "Skipping $($module.ModuleName) $($module.RequiredVersion): already available"
    }
}