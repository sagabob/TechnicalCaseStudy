param location string 
param namePrefix string
param uniqueSuffix string

@description('Retention days for the log analytics workspace')  
@minValue(7)
@maxValue(10)
param retentionInDays int = 7
param tags object = {}


var logAnalyticsWorkspaceName = toLower(take('law-${replace(namePrefix, '-', '')}-${uniqueSuffix}', 63))


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'Free'
    }
    retentionInDays: retentionInDays   
    
  }
  tags: tags
}
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
