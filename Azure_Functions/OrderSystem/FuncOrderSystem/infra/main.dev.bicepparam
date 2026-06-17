using './main.bicep'

param environment = 'dev'
param location = 'australiaeast'
param namePrefix = 'func-order'
param serviceBusSku = 'Standard'
param queueName = 'orders-queue'

param tags = {
  project: 'func-order-system'
  environment: 'dev'
}
