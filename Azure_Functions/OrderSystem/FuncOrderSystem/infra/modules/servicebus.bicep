@description('Azure region for Service Bus resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Suffix to keep namespace names globally unique.')
param uniqueSuffix string

@description('Optional resource tags.')
param tags object = {}

@description('Service Bus SKU. Basic supports queues only (lowest cost).')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Basic'

@description('Name of the orders queue.')
param queueName string = 'orders-queue'

var namespaceName = take('sb-${namePrefix}-${environment}-${uniqueSuffix}', 50)

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource ordersQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    enablePartitioning: false
  }
}

resource sendListenRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-01-01-preview' = {
  parent: serviceBusNamespace
  name: 'app-send-listen'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

var sendListenRuleId = resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceBusNamespace.name, sendListenRule.name)

output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusFqdn string = '${serviceBusNamespace.name}.servicebus.windows.net'
output queueName string = ordersQueue.name
output authorizationRuleName string = sendListenRule.name

@secure()
output serviceBusConnectionString string = listKeys(sendListenRuleId, '2022-01-01-preview').primaryConnectionString
