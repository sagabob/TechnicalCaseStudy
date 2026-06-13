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

module network './modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    environment: environment
    tags: tags
  }
}

module storage './modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

module web './modules/web.bicep' = {
  name: 'web-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    environment: environment
    uniqueSuffix: uniqueSuffix
    tags: tags
    blobEndpoint: storage.outputs.blobEndpoint
    uploadsContainerName: storage.outputs.uploadsContainerName
    storageAccountName: storage.outputs.storageAccountName
    appServiceIntegrationSubnetId: network.outputs.appServiceIntegrationSubnetId
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output blobEndpoint string = storage.outputs.blobEndpoint
output uploadsContainerName string = storage.outputs.uploadsContainerName
output thumbnailsContainerName string = storage.outputs.thumbnailsContainerName
output appServicePlanName string = web.outputs.appServicePlanName
output webAppName string = web.outputs.webAppName
output webAppUrl string = web.outputs.webAppUrl
output webAppPrincipalId string = web.outputs.webAppPrincipalId
output vnetName string = network.outputs.vnetName
output vnetId string = network.outputs.vnetId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output appServiceIntegrationSubnetId string = network.outputs.appServiceIntegrationSubnetId
