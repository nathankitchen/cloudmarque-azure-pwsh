function Set-BlobStorageContentType {
	<#
        .Synopsis
         Sets blobs of specific file types in storage to another content type.

        .Description
         Sets blobs of specific file types in storage to another content type, e.g .js is set to Application/Javascript

        .Parameter ResourceGroupName
         The name of the resource group where the blob storage account is located.

		.Parameter StorageName
         The name of the blob storage account.

        .Component
         PaaS

        .Example
         SetBlobStorageContentTypes -ResourceGroupName "myResourceGroup" -StorageName "myStorage"
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [String]$StorageName
    )

    if($PSCmdlet.ShouldProcess((Get-CmAzSubscriptionName), "Set content in $Storage")) {

        Write-Verbose "Getting storage key..."
        $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $StorageName).Value[0]

        Write-Verbose "Creating storage context..."
        $context = New-AzStorageContext -StorageAccountName $StorageName -StorageAccountKey $storageAccountKey

        $typeMappings = @{
            ".js" = "application/javascript"
        }

        $blobs = Get-AzStorageBlob -Container '$web' -Context $context

        foreach ($blob in $blobs)
        {
            Write-Verbose "Processing Blob: $($blob.Name)..."

            $extn = [IO.Path]::GetExtension($Blob.Name)
            $contentType = $typeMappings[$extn]

            if ($contentType) {

                Write-Verbose "Blob file extension is $($Extn) - this will change the content type to $($contentType)..."
                $CloudBlockBlob = [Microsoft.Azure.Storage.Blob.CloudBlockBlob] $blob.ICloudBlob

                $CloudBlockBlob.Properties.ContentType = $contentType
                $task = $CloudBlockBlob.SetPropertiesAsync()
                $task.Wait()

                Write-Verbose $task.Status
            }
        }

        Write-Verbose "Finished!"
    }
}

