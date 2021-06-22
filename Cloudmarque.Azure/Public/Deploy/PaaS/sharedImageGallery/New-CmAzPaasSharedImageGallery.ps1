function New-CmAzPaasSharedImageGallery {

    <#
		.Synopsis
         Creates shared images gallery

		.Description
		 Completes following:
			* Creates Shared Image Gallery
			* Creates image definition inside shared image gallery
            * Adds Images to image definition

		.Parameter SettingsFile
         File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
         Object containing the configuration values required to run this cmdlet.

		.Component
         PaaS

		.Example
         New-CmAzPaasSharedImageGallery -SettingsFile ./sharedImageGallery.yml

		.Example
		 New-CmAzPaasSharedImageGallery -SettingsObject $settings
	#>

    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "Settings File")]
        [String]$SettingsFile,
        [parameter(Mandatory = $true, ParameterSetName = "Settings Object")]
        [Object]$SettingsObject
    )

    $ErrorActionPreference = "Stop"

    try {

        Get-InvocationInfo -CommandName $MyInvocation.MyCommand.Name

        $SettingsObject = Get-Settings -SettingsFile $SettingsFile -SettingsObject $SettingsObject -CmdletName (Get-CurrentCmdletName -ScriptRoot $PSCommandPath)

        if ($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Deploy shared image gallery")) {

            $resourceGroup = Get-CmAzService -Service $SettingsObject.resourceGroupServiceTag -IsResourceGroup

            if (!$resourceGroup -and $SettingsObject.resourceGroupName) {
                $rgCheck = Get-AzResourceGroup -Name $SettingsObject.resourceGroupName -ErrorAction SilentlyContinue

                if (!$rgCheck) {
                    $generatedRG = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "PaaS" -Name $SettingsObject.resourceGroupName -Location $SettingsObject.Location
                    New-AzResourceGroup -ResourceGroupName $generatedRG -Tag @{"cm-service" = $SettingsObject.resourceGroupServiceTag } -Location $SettingsObject.Location
                }
                else {
                    Write-Error "Resource Group by provided name already exists.`nPlease provide appropriate service tag for existing resource group or provide unique name to create new."
                }
            }
            elseif (!$resourceGroup -and !$SettingsObject.resourceGroupName) {
                Write-Error "Please provide appropriate service tag for existing resource group or provide unique name to create new."
            }

            $SettingsObject.galleryName = Get-CmAzResourceName -Resource "SharedImageGallery" -Architecture "Paas" -Location $SettingsObject.location -Name $SettingsObject.galleryName

            $SettingsObject.imageDefinitions | ForEach-Object {

                Write-Verbose "Validating ImageDefinition: $($_.definitionName)"

                if ($_.endOfLifeDate) {
                    $_.endOfLifeDate = (([datetime]::Parse($_.endOfLifeDate)).GetDateTimeFormats('s')).Split()
                }
                else {
                    $date = ((Get-date).AddYears('2').GetDateTimeFormats('s')).split()

                    $_.endOfLifeDate = $date
                    Write-Verbose "Default: End of life date will be set to : $date"
                }

                if (!$_.location) {
                    $_.location = $SettingsObject.location
                    Write-Verbose "Default: image definition location will be defaulted Shared imaged gallery : $($SettingsObject.location)"
                }

                if (!$_.osType) {
                    $_.osType = "Linux"
                    Write-Verbose "Default: OS type will be set to - $($_.osType)"
                }

                if (!$_.osState) {
                    $_.osState = "Generalized"
                    Write-Verbose "Default: OS state will be set to : $($_.osState)"
                }

                if (!$_.vCPUs) {
                    $_.vCPUs = ""
                }

                if (!$_.memory) {
                    $_.memory = ""
                }

                $_.versions | ForEach-Object {

                    if (!$_.version -or !$_.imageServiceTag -or !$_.targetLocations) {
                        Write-Error "Settings file is missing required parameters. Please check if version, imageServiceTag and targetLocations are defined."
                    }

                    if ($_.endOfLifeDate) {
                        $_.endOfLifeDate = (([datetime]::Parse($_.endOfLifeDate)).GetDateTimeFormats('s')).Split()
                    }
                    else {
                        $_.endOfLifeDate = $date
                        Write-Verbose "Default: End of life date will be set to : $date"
                    }

                    if (!$_.replicaCount) {
                        $_.replicaCount = "1"
                        Write-Verbose "Default: Replication count will be set to 1."
                    }

                    $_.image = Get-CmAzService -Service $_.imageServiceTag -ThrowIfUnavailable

                    if ($_.targetLocations -notcontains $_.image.location) {
                        $_.targetLocations.add($_.image.location)
                        Write-Verbose "Default: A copy of image version is always required in managed image location. $($_.image.location) will be added to target locations."
                    }

                }

            }

            Write-Verbose "Deploying Shared Image Gallery..."

            $deploymentName = Get-CmAzResourceName -Resource "Deployment" -Architecture "Paas" -Location $SettingsObject.location -Name "New-CmAzPaasSharedImageGallery"

            New-AzResourceGroupDeployment `
                -Name $deploymentName `
                -ResourceGroupName $resourceGroup.ResourceGroupName `
                -TemplateFile "$PSScriptRoot\New-CmAzPaasSharedImageGallery.json" `
                -Location $SettingsObject.location `
                -ImageDefinitions $SettingsObject.imageDefinitions `
                -GalleryName $SettingsObject.galleryName `
                -Force
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSitem);
    }
}