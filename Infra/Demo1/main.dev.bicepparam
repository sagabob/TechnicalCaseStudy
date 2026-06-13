using './main.bicep'



// Committed config only. secrets.bicepparam extends this file and adds passwords (see secrets.bicepparam.example).



param environment = 'dev'

param location = 'australiaeast'

param namePrefix = 'demo1'

param vmAdminUsername = 'azureuser'



param tags = {

  project: 'demo1-hub-spoke'

  environment: 'dev'

}


