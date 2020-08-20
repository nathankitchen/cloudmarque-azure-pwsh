function Install-Dependencies() {

    <#
        .Synopsis
        Installs dependencies in order to use Cloudmarque.Azure

        .Example
        . ./Install-Dependencies
        Install-Dependencies
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Array]
        $AdditionalModules,
        [ValidateSet("Auto","AllUsers","CurrentUser")]
        [String]
        $Scope = "Auto"
    )

    if($PSCmdlet.ShouldProcess("Cloudmarque.Azure", "Install dependencies")) {

        $modules = @(
            @{ Name = "Powershell-Yaml"; Version = "0.4.1" }
            @{ Name = "Az.Accounts"; Version = "1.7.5" }
        )

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

            Write-Verbose "Looking for $($module.Name) version $($module.Version)..."

            if (!(Get-Module -Name $module.Name | Where-Object { ($_.Version -Join ".") -Eq $module.Version })) {

                Write-Verbose "Not imported, checking whether it's installed..."

                if (!(Get-Module -ListAvailable -Name $module.Name | Where-Object { ($_.Version -Join ".") -Eq $module.Version })) {
                    Write-Verbose "Installing $($module.Name) for $resolvedScope..."
                    Install-Module -Name $module.Name -RequiredVersion $module.Version -Scope $resolvedScope -Force -AllowClobber -SkipPublisherCheck
                }

                Write-Verbose "Importing $($module.Name) version $($module.Version)..."
                try {
                    Import-Module -Name $module.Name -RequiredVersion $module.Version -Force
                }catch [System.IO.FileLoadException] {
                    $_.ToString() | Write-Verbose
                }catch {
                    $_
                    break
                }
            }
            else {
                Write-Verbose "Skipping $($module.Name) $($module.Version): already available"
            }
        }
    }
}