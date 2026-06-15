@description('Azure region for hub resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Optional resource tags.')
param tags object = {}

@description('Hub virtual network address space.')
param hubAddressPrefix string = '10.0.0.0/16'

@description('Azure Bastion subnet (must be named AzureBastionSubnet, minimum /26).')
param bastionSubnetPrefix string = '10.0.1.0/26'

var hubVnetName = 'vnet-hub-${namePrefix}-${environment}'

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output bastionSubnetId string = '${hubVnet.id}/subnets/AzureBastionSubnet'
output bastionSubnetPrefix string = bastionSubnetPrefix
