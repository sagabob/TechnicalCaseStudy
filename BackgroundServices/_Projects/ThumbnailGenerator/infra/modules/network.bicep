@description('Azure region for network resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Optional resource tags.')
param tags object = {}

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet for private endpoints.')
param privateEndpointSubnetPrefix string = '10.0.1.0/24'

@description('Subnet for App Service regional VNet integration.')
param appServiceSubnetPrefix string = '10.0.2.0/24'

var vnetName = 'vnet-${namePrefix}-${environment}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-appservice'
        properties: {
          addressPrefix: appServiceSubnetPrefix
          delegations: [
            {
              name: 'appservice-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output privateEndpointSubnetId string = '${vnet.id}/subnets/snet-private-endpoints'
output appServiceIntegrationSubnetId string = '${vnet.id}/subnets/snet-appservice'
