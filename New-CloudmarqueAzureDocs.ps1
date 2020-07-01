function New-CloudmarqueAzureDocs {

    <#
        .Synopsis
         Publishes a new version of the Cloudmarque Azure Powershell tooling.
    
        .Description
         Sets the target version number for the module, and then both packs and publishes
         the module as a NuGet package.
    
        .Example
         Publish-CloudmarqueAzure -Package "$PSScriptRoot\publish\pkg\$module.*.nupkg"
    #>

    . ./Install-Dependencies.ps1

    Install-Dependencies -Verbose

    Import-Module "$PSScriptRoot/Cloudmarque.Azure" -Force

    if (!(Test-Path -Path "$PSScriptRoot/publish/")) { New-Item "$PSScriptRoot/publish/" -ItemType Directory }
    if (!(Test-Path -Path "$PSScriptRoot/publish/docs/")) { New-Item "$PSScriptRoot/publish/docs/" -ItemType Directory }

    $commands = Get-Command -Module "Cloudmarque.Azure"
    $content = Get-Content -Path "$PSScriptRoot/docs-template.md" -Encoding UTF8 -Raw
    $content = $content -Replace '"', '`"'
    $content = $content -Replace '''', '`'''

    foreach ($command in $commands) {
        $help = Get-Help -Name $command.Name -Full
        $filename = $command.Name.ToLower() + ".md"

        $docsObj = @{
            "title" = $command.Name
            "summary" = $help.synopsis;
            "description" = $help.description.Text;
            "component" = $help.component;
            "category" = $help.category;
            "parameters"=@();
            "examples"=@();
        };

        foreach ($parameter in $help.parameters.parameter) {
            $p = @{
                "name"="$($parameter.name)";
                "type"= "$($parameter.type.name)";
                "default"= "$($parameter.defaultValue)";
                "required"= $parameter.required;
                "globbing"= $parameter.globbing;
                "position"= $parameter.position;
                "description"= $parameter.description.Text;
            };

            $docsObj.parameters = $docsObj.parameters + $p;
        }

        foreach ($example in $help.examples.example) {

            $remarks = "";
            foreach ($remark in $example.remarks.text) {
                $remarks += $remark;
            }

            $e = @{
                "title"="$($example.code)";
                "remarks"="$($remarks)";
            };

            $docsObj.examples = $docsObj.examples + $e;
        }

        $docs = ConvertTo-Yaml -Data $docsObj
        $doc = $ExecutionContext.InvokeCommand.ExpandString($content)

        Set-Content -Path "$PSScriptRoot/publish/docs/$filename" -Value $doc
    }
}