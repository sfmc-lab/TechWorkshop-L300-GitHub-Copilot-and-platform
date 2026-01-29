targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., dev, staging, prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'westus3'

@description('Name of the application')
param appName string = 'zavastore'

// Generate unique suffix for resource names
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'application': appName
}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${appName}-${environmentName}-${location}'
  location: location
  tags: tags
}

// Log Analytics Workspace
module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  scope: rg
  params: {
    name: 'log-${appName}-${resourceToken}'
    location: location
    tags: tags
  }
}

// Application Insights
module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights'
  scope: rg
  params: {
    name: 'appi-${appName}-${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Azure Container Registry
module acr 'modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    name: 'acr${appName}${resourceToken}'
    location: location
    tags: tags
  }
}

// App Service (Linux Web App for Containers)
module appService 'modules/appService.bicep' = {
  name: 'appService'
  scope: rg
  params: {
    appServicePlanName: 'plan-${appName}-${resourceToken}'
    webAppName: 'app-${appName}-${resourceToken}'
    location: location
    tags: tags
    acrName: acr.outputs.name
    acrLoginServer: acr.outputs.loginServer
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
  }
}

// Azure AI Foundry (Cognitive Services)
module aiFoundry 'modules/aiFoundry.bicep' = {
  name: 'aiFoundry'
  scope: rg
  params: {
    name: 'ai-${appName}-${resourceToken}'
    location: location
    tags: tags
    appServicePrincipalId: appService.outputs.principalId
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// Outputs
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.loginServer
output AZURE_APP_SERVICE_NAME string = appService.outputs.name
output AZURE_APP_SERVICE_URL string = appService.outputs.url
output AZURE_AI_FOUNDRY_NAME string = aiFoundry.outputs.name
output AZURE_AI_FOUNDRY_ENDPOINT string = aiFoundry.outputs.endpoint
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.outputs.connectionString
