param location string = resourceGroup().location

param namePrefix string = 'sample1'

@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Standard_GZRS', 'Standard_RAGZRS'])
param skuName string = 'Standard_GRS'

@allowed(['StorageV2', 'BlobStorage', 'BlockBlobStorage', 'FileStorage', 'Storage'])
param kind string = 'StorageV2'


param uniqueSuffix string = uniqueString(resourceGroup().id, namePrefix, environment)
param tags object = {
  project: 'sample1-storage'
  environment: environment
}


module storage './modules/storages/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    tags: tags
    skuName: skuName
    kind: kind
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output storageAccountId string = storage.outputs.storageAccountId
output storageBlobEndpoint string = storage.outputs.storageBlobEndpoint
output storageQueueEndpoint string = storage.outputs.storageQueueEndpoint
output storageTableEndpoint string = storage.outputs.storageTableEndpoint
output storageFileEndpoint string = storage.outputs.storageFileEndpoint

