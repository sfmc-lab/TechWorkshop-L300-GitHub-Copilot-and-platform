@description('Name of the Azure AI Services resource')
param name string

@description('Location for the resource')
param location string

@description('Tags for the resource')
param tags object = {}

@description('SKU for the AI Services')
@allowed(['S0', 'F0'])
param sku string = 'S0'

@description('Principal ID of the App Service managed identity for role assignment')
param appServicePrincipalId string = ''

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Disable local authentication (API keys) and enforce managed identity only. Set to true for production security.')
param disableLocalAuth bool = false

// Azure AI Services (formerly Cognitive Services)
resource aiServices 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: sku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: disableLocalAuth
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// GPT-4o model deployment (available in westus3 with GlobalStandard)
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: aiServices
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-08-06'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

// Note: Phi models can be added via Azure Portal after deployment
// Model availability varies by region and subscription

// Cognitive Services User role assignment for App Service managed identity
resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appServicePrincipalId)) {
  name: guid(aiServices.id, appServicePrincipalId, 'cognitive-services-user')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic settings to send all logs to Log Analytics
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${aiServices.name}-diagnostics'
  scope: aiServices
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output id string = aiServices.id
output name string = aiServices.name
output endpoint string = aiServices.properties.endpoint
output principalId string = aiServices.identity.principalId
