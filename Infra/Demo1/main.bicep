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

param namePrefix string = 'demo1'



@description('Optional resource tags.')

param tags object = {

  project: 'demo1-hub-spoke'

  environment: environment

}



@description('VM administrator username.')

param vmAdminUsername string = 'azureuser'



@secure()

@description('VM administrator password. Stored in Key Vault during deployment.')

param vmAdminPassword string = ''



var uniqueSuffix = uniqueString(resourceGroup().id, namePrefix, environment)



module keyVault './modules/keyvault.bicep' = {

  name: 'keyvault-deployment'

  params: {

    location: location

    namePrefix: namePrefix

    uniqueSuffix: uniqueSuffix

    tags: tags

    vmAdminPassword: vmAdminPassword

  }

}



module hub './modules/hub.bicep' = {

  name: 'hub-deployment'

  params: {

    location: location

    namePrefix: namePrefix

    environment: environment

    tags: tags

  }

}



module spoke './modules/spoke.bicep' = {

  name: 'spoke-deployment'

  params: {

    location: location

    namePrefix: namePrefix

    environment: environment

    tags: tags

    bastionSubnetPrefix: hub.outputs.bastionSubnetPrefix

  }

}



module peering './modules/peering.bicep' = {

  name: 'peering-deployment'

  params: {

    hubVnetName: hub.outputs.hubVnetName

    spokeVnetName: spoke.outputs.spokeVnetName

  }

}



module bastion './modules/bastion.bicep' = {

  name: 'bastion-deployment'

  params: {

    location: location

    namePrefix: namePrefix

    environment: environment

    tags: tags

    bastionSubnetId: hub.outputs.bastionSubnetId

  }

}



module vm './modules/vm.bicep' = {

  name: 'vm-deployment'

  params: {

    location: location

    namePrefix: namePrefix

    environment: environment

    tags: tags

    vmSubnetId: spoke.outputs.vmSubnetId

    adminUsername: vmAdminUsername

    adminPassword: vmAdminPassword

  }

}



output keyVaultName string = keyVault.outputs.keyVaultName

output vmAdminUsername string = vmAdminUsername

output hubVnetName string = hub.outputs.hubVnetName

output spokeVnetName string = spoke.outputs.spokeVnetName

output bastionHostName string = bastion.outputs.bastionHostName

output vmName string = vm.outputs.vmName

output vmPrivateIpAddress string = vm.outputs.vmPrivateIpAddress

output vmConnectHint string = 'Bastion RDP → ${vm.outputs.vmName}. Username: ${vmAdminUsername}. Password: Key Vault secret vm-admin-password in ${keyVault.outputs.keyVaultName}. Install SSMS from the VM after connect.'


