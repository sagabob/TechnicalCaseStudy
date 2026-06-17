az login
az group create --name rg-sample-1 --location AustraliaEast


az deployment group validate --resource-group rg-sample-1   --parameters main.dev.bicepparam

az deployment group what-if   --resource-group rg-sample-1    --parameters main.dev.bicepparam


az deployment group create   --resource-group rg-sample-1    --parameters main.dev.bicepparam  