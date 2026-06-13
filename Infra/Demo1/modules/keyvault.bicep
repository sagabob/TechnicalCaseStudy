@description('Azure region for Key Vault.')

param location string



@description('Short prefix used in resource names.')

param namePrefix string



@description('Suffix to keep Key Vault names globally unique.')

param uniqueSuffix string



@description('Optional resource tags.')

param tags object = {}



@secure()

@description('VM administrator password to store as a secret.')

param vmAdminPassword string



var keyVaultName = take('kv${replace(namePrefix, '-', '')}${uniqueSuffix}', 24)



resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {

  name: keyVaultName

  location: location

  tags: tags

  properties: {

    tenantId: subscription().tenantId

    sku: {

      family: 'A'

      name: 'standard'

    }

    enableRbacAuthorization: false

    enableSoftDelete: true

    softDeleteRetentionInDays: 7

    accessPolicies: [

      {

        tenantId: subscription().tenantId

        objectId: deployer().objectId

        permissions: {

          secrets: [

            'get'

            'list'

            'set'

            'delete'

          ]

        }

      }

    ]

  }

}



resource vmAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {

  parent: keyVault

  name: 'vm-admin-password'

  properties: {

    value: vmAdminPassword

  }

}



output keyVaultName string = keyVault.name

output keyVaultUri string = keyVault.properties.vaultUri


