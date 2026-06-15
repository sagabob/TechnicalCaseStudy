@description('Azure region for Bastion resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Optional resource tags.')
param tags object = {}

@description('Azure Bastion subnet resource ID.')
param bastionSubnetId string

var bastionName = 'bas-${namePrefix}-${environment}'
var bastionPipName = 'pip-bas-${namePrefix}-${environment}'

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: bastionPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ip-config'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

output bastionHostName string = bastionHost.name
output bastionPublicIpAddress string = bastionPublicIp.properties.ipAddress
