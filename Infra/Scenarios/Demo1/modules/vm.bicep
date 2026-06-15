@description('Azure region for the virtual machine.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Optional resource tags.')
param tags object = {}

@description('Subnet resource ID for the VM network interface.')
param vmSubnetId string

@description('VM administrator username.')
param adminUsername string

@secure()
@description('VM administrator password.')
param adminPassword string

@description('VM size SKU. B2ms (8 GB RAM) recommended for Windows + SSMS.')
param vmSize string = 'Standard_B2ms'

@description('Windows Server image SKU.')
param vmImageSku string = '2022-datacenter-azure-edition-smalldisk'

var vmName = 'vm-${namePrefix}-${environment}'
var nicName = 'nic-${namePrefix}-${environment}'
var computerName = take(replace('${namePrefix}${environment}', '-', ''), 15)

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vmSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: vmImageSku
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

output vmName string = vm.name
output vmPrivateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmPrincipalId string = vm.identity.principalId
