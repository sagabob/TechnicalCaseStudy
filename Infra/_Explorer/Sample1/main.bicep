param location string = resourceGroup().location

param namePrefix string = 'sample1'

@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'


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
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output storageAccountId string = storage.outputs.storageAccountId
