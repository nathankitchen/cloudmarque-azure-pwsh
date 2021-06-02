function Build-PrivateEndpoints {

    param (

        [parameter(Mandatory = $true)]
        [Hashtable]$SettingsObject,
        [parameter(Mandatory = $true)]
        [string]$LookupProperty,
        [Hashtable]$GlobalServiceContainer,
        [string]$NameProperty = "name",
        [string]$ResourceName,
        [string]$GlobalSubResourceName,
        [string]$GlobalResourceNameSpace
    )

    if ($GlobalServiceContainer) {
        $SettingsObject.service = $GlobalServiceContainer
    }

    $filteredObject = $SettingsObject.$LookupProperty | Where-Object { $_.privateEndpoints }

    Foreach ($resourceObject in $filteredObject) {

        $index = 0

        Foreach ($endpoint in $resourceObject.privateEndpoints) {

            $endpoint.name ??= $resourceObject.$NameProperty ? "$index-$($resourceObject.$NameProperty)" : "$index-$($SettingsObject.$NameProperty)"
            $endpoint.location ??= $resourceObject.location ? $resourceObject.location : $SettingsObject.location
            $endpoint.service.dependencies.resource ??= $resourceObject.service.publish.$ResourceName ? $resourceObject.service.publish.$ResourceName  : $SettingsObject.service.publish.$ResourceName

            # Resource group is a dependency for private endpoint but most of the resources create resource groups within. Private endpoints are deployed in these resource groups.
            $endpoint.service.dependencies.resourceGroup ??= $resourceObject.service.publish.resourceGroup ? $resourceObject.service.publish.resourceGroup : $SettingsObject.service.publish.resourceGroup
            $endpoint.resourceNameSpace ??= $GlobalResourceNameSpace
        }
    }

    $privateEndpointObject = @{
        service = @{
            publish = @{
                privateEndpoint =  $SettingsObject.service.publish.privateEndpoint
            };
            dependencies = @{
                resourceGroup = $SettingsObject.service.dependencies.resourceGroup ? $SettingsObject.service.dependencies.resourceGroup : $SettingsObject.service.publish.resourceGroup;
                vnet =	$SettingsObject.service.dependencies.vnet;
            };
        };

        globalSubResourceName = $GlobalSubResourceName

        privateEndpoints = $filteredObject.privateEndpoints -is [array] ? $filteredObject.privateEndpoints : @($filteredObject.privateEndpoints)
    }

    New-CmAzIaasPrivateEndpoints -SettingsObject $privateEndpointObject -OmitTags $true
}