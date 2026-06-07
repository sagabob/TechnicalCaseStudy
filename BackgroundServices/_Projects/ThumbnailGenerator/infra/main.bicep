targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name (dev, test, prod).')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Short prefix used in resource names.')
param namePrefix string = 'tcs-thumb'

@description('Optional resource tags.')
param tags object = {
  project: 'thumbnail-generator'
  environment: environment
}

var uniqueSuffix = uniqueString(resourceGroup().id, namePrefix, environment)

module storage './modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output blobEndpoint string = storage.outputs.blobEndpoint
output uploadsContainerName string = storage.outputs.uploadsContainerName
output thumbnailsContainerName string = storage.outputs.thumbnailsContainerName
