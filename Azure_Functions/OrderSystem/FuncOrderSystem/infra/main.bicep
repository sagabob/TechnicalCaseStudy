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
param namePrefix string = 'func-order'

@description('Optional resource tags.')
param tags object = {
  project: 'func-order-system'
  environment: environment
}

@description('Service Bus SKU. Basic supports queues only.')
@allowed([
  'Basic'
  'Standard'
])
param serviceBusSku string = 'Standard'

@description('Name of the orders queue.')
param queueName string = 'orders-queue'

var uniqueSuffix = uniqueString(resourceGroup().id, namePrefix, environment)

module serviceBus './modules/servicebus.bicep' = {
  name: 'servicebus-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    environment: environment
    uniqueSuffix: uniqueSuffix
    tags: tags
    skuName: serviceBusSku
    queueName: queueName
  }
}

output serviceBusNamespaceName string = serviceBus.outputs.serviceBusNamespaceName
output serviceBusFqdn string = serviceBus.outputs.serviceBusFqdn
output queueName string = serviceBus.outputs.queueName
@secure()
output serviceBusConnectionString string = serviceBus.outputs.serviceBusConnectionString
output localSettingsHint string = 'Set SERVICE_BUS_CONNECTION_STRING and QUEUE_NAME=${queueName} in local.settings.json. In Azure use SERVICE_BUS_FQDN=${serviceBus.outputs.serviceBusFqdn} with managed identity.'
