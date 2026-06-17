using './main.bicep'

param environment = 'dev'
param location = 'australiaeast'
param namePrefix = 'sample1'


param tags = {
  project: 'sample1-infra'
  environment: 'dev'
}
