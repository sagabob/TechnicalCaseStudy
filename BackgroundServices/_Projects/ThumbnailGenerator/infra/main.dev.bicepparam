using './main.bicep'

param environment = 'dev'
param location = 'australiaeast'
param namePrefix = 'tcs-thumb'

param tags = {
  project: 'thumbnail-generator'
  environment: 'dev'
}
