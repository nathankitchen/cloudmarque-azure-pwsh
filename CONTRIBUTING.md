# Contributing to Cloudmarque.Azure

## Set up a development environment

   1. ### Install dependencies
      The following pre-requisites are required:

      1. Install [Git](https://git-scm.com/downloads)
      2. Install [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7)
      3. Install [Azure PowerShell Modules](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)

      #### OPTIONAL: Install Visual Studio Code
      Visual Studio Code (VSCode) is the recommended IDE for developing Cloudmarque.Azure. VSCode is a free IDE developed by Microsoft and the open source community. It is available online via a browser as part of [Visual Studio Online](https://visualstudio.microsoft.com/services/visual-studio-online/), and can also be installed locally across Windows, Mac, and Linux.

      These instructions provide typical defaults for a local installation.

      1. Download and install Visual Studio Code from [https://code.visualstudio.com/]

      2. In the Extensions tab, search for and install:
         * [Material Icon Theme](https://marketplace.visualstudio.com/items?itemName=PKief.material-icon-theme)
         * [PowerShell](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)
         * [Prettify JSON](https://marketplace.visualstudio.com/items?itemName=mohsen1.prettify-json)
         * [Azure Repos](https://marketplace.visualstudio.com/items?itemName=ms-vsts.team)
         * [Azure Account](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azure-account)
         * [Liquid](https://marketplace.visualstudio.com/items?itemName=sissel.shopify-liquid)
         * [Sass](https://marketplace.visualstudio.com/items?itemName=Syler.sass-indented)
         * [GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)
         * [YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

      3. Perform any personal quality-of-life changes to customise the environment to your liking:
         * Set your favourite [theme](https://code.visualstudio.com/docs/getstarted/themes)
         * Tweak [settings](https://code.visualstudio.com/docs/getstarted/settings)
         
           **NB:** _Users familiar with Visual Studio Pro/Enterprise may particularly want to set `"workbench.sideBar.location": "right"` to move the side panel (File Explorer, Source Control, Extensions, etc) to the right._

   2. ### Clone the repository

   ``` bash
   git clone 
   ```

   If you want to access an existing topic branch, use:

   ``` bash
   git checkout [branch-name]
   ```

   3. ### Create a development branch

   ``` bash
   git branch topic-<Your feature name>
   ```

## Build and Test
A suite of build tasks are defined in the root of the project. These can all be imported by running a convenient helper method: `. .\init.ps1`.

| Command                    | Description                                                             |
| -------------------------- | ----------------------------------------------------------------------- |
| `Sync-CloudmarqueAzure`    | Removes and re-imports the module in the current PS session             |
| `Build-CloudmarqueAzure`   | Creates the Nuget Package                                               |
| `Test-CloudmarqueAzure`    | Runs automated tests                                                    |
| `Publish-CloudmarqueAzure` | Publishes the package to the source repository as part of CI/CD process |

Bear in mind that these commands will need to be dot-sourced whenever they are changed in order to import the updated version into the current PowerShell session.

## Open a pull request (?)

## Versioning

## Coding Standards[]()

## General[]()
  
* Cmdlets should contain at least the equivalent of the following documentation:
        
    .Synopsis
		 Creates keyvaults for a specified resource group in the current subscription.

		.Description
		 Completes the following:
			* Deploys multiple keyvaults in multiple locations to a specified resource group.
			* Adds diagnostic settings linking the keyvaults to the core workspace.
			* Adds activity log alert rules for whenever an auditevent is raised in any of the keyvaults.

		.Parameter SettingsFile
		 File path for the settings file to be converted into a settings object.

		.Parameter SettingsObject
		 Object containing the configuration values required to run this cmdlet.

		.Component
		 Core

		.Example
   	 New-CmAzCoreBillingRule -SettingsFile "c:/directory/settingsFile.yml"

    .Example
	 	 New-CmAzCoreBillingRule -SettingsObject $settings
	#>

* Make sure yml files are named in lowercase with an extension of .yml and have their properties in camelcase.

* Write pester tests for any additional functionality created. Ensure all positive and negative test paths are covered where appropriate.

* All cmdlets need to utilise ShouldProcess for any code likely to cause side effects, e.g. resource deployment. Set ConfirmImpact accordingly to the following examples:

  * Cmdlets with little to no side effects 					-> Small
  * Small scale resource deployment 							-> Medium
  * Destructive or large scale resource deployment       -> High

* Error handling pattern (to follow..)

## Resource Deployment[]()
    
* Cmdlets deploying resources should utilise the pattern below for their parameters:
        
      [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")] 
      param(
        [parameter(Mandatory=true, ParameterSetName = "Settings File")] 
        [String]SettingsFile, 
        [parameter(Mandatory=true, ParameterSetName = "Settings Object")] 
        [Object]SettingsObject 
      )
    
			if ($SettingsFile -and !$SettingsObject) {
				$SettingsObject = Get-CmAzSettingsFile -Path $SettingsFile
			}
			elseif (!$SettingsFile -and !$SettingsObject) {
				Write-Error "No valid input settings." -Category InvalidArgument -CategoryTargetName "SettingsObject"
			}

* Utilise Get-CmAzSettingsFile for fetching any json or yml files and converting them into PSObjects, this will also test the path of the file passed in.

* Use Get-CmAzResourceName for all resource naming.

* Add a custom name as a parameter to all deployments to provide contextual info for resources being deployed. Ensure this value is passed into -name of      
  Get-CmAzResourceName for each resource.

* Merge multiple ARM templates used for a specific deployment where possible.

* Parallelise deployment of ARM templates (otherwise powershell) where possible.

* Avoid duplicating validation provided by the Azure deployment process e.g. avoid validating on date ranges and name lengths etc.

* Add testing for all deployment files (to follow..)

* Utilise existing ARM template functions to fetch resource details e.g. subscription(), resourceGroup() where possible 








