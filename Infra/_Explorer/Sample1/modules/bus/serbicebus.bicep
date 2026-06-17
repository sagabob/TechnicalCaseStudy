param location string
param namePrefix string
param environment string
param uniqueSuffix string
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Basic'
param capacity int = 1
@allowed([
  'Basic'
  'Standard'
])
param tier string = 'Basic'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: '${namePrefix}-${environment}-${uniqueSuffix}'
  location: location
  sku: {
    name: skuName
    capacity: capacity
    tier: tier
  }
  tags: {
    environment: environment
    project: 'sample-1'
  }
}

output serviceBusNamespaceName string = serviceBusNamespace.name
output serviceBusNamespaceId string = serviceBusNamespace.id
