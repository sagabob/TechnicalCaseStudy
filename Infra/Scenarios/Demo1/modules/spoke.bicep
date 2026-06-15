@description('Azure region for spoke resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Optional resource tags.')
param tags object = {}

@description('Hub Bastion subnet prefix for NSG inbound rules.')
param bastionSubnetPrefix string

@description('Spoke virtual network address space.')
param spokeAddressPrefix string = '10.1.0.0/16'

@description('Subnet for the application virtual machine.')
param vmSubnetPrefix string = '10.1.0.0/24'

var spokeVnetName = 'vnet-spoke-${namePrefix}-${environment}'
var vmNsgName = 'nsg-vm-${namePrefix}-${environment}'

resource vmNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: vmNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Bastion'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: spokeVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: vmSubnetPrefix
          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
    ]
  }
}

output spokeVnetId string = spokeVnet.id
output spokeVnetName string = spokeVnet.name
output vmSubnetId string = '${spokeVnet.id}/subnets/snet-vm'
