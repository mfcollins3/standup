// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

targetScope = 'subscription'

@description('The name of the environment (e.g. dev, qa, prod).')
@minLength(1)
@maxLength(64)
param environmentName string

@description('The Azure region in which to deploy resources.')
@minLength(1)
param location string

@description('The publisher email address for the API Management instance.')
param publisherEmail string = 'support@nakedstandup.app'

@description('The publisher name for the API Management instance.')
param publisherName string = 'Naked Standup'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

var tags = {
	'azd-env-name': environmentName
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
	name: '${abbrs.resourceGroup}-standup-${environmentName}'
	location: location
	tags: tags
}

module monitoring './modules/monitoring.bicep' = {
	name: 'monitoring'
	scope: resourceGroup
	params: {
		name: '${abbrs.applicationInsights}-standup-${resourceToken}'
		logAnalyticsWorkspaceName: '${abbrs.logAnalyticsWorkspace}-standup-${resourceToken}'
		location: location
		tags: tags
	}
}

module storage './modules/storage.bicep' = {
	name: 'storage'
	scope: resourceGroup
	params: {
		name: '${abbrs.storageAccount}standup${resourceToken}'
		location: location
		tags: tags
	}
}

module functionApp './modules/function-app.bicep' = {
	name: 'function-app'
	scope: resourceGroup
	params: {
		name: '${abbrs.functionApp}-standup-${resourceToken}'
		planName: '${abbrs.appServicePlan}-standup-${resourceToken}'
		location: location
		tags: tags
		storageAccountId: storage.outputs.id
		storageAccountName: storage.outputs.name
		storageAccountBlobEndpoint: storage.outputs.primaryBlobEndpoint
		appInsightsConnectionString: monitoring.outputs.connectionString
	}
}

module keyVault './modules/key-vault.bicep' = {
	name: 'key-vault'
	scope: resourceGroup
	params: {
		name: '${abbrs.keyVault}-standup-${resourceToken}'
		location: location
		tags: tags
		functionAppPrincipalId: functionApp.outputs.principalId
		apimPrincipalId: apim.outputs.principalId
		logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
	}
}

module apim './modules/api-management.bicep' = {
	name: 'api-management'
	scope: resourceGroup
	params: {
		name: '${abbrs.apiManagement}-standup-${resourceToken}'
		location: location
		tags: tags
		functionAppUrl: functionApp.outputs.defaultHostName
		functionKey: functionApp.outputs.hostKey
		publisherEmail: publisherEmail
		publisherName: publisherName
		appInsightsId: monitoring.outputs.id
		appInsightsInstrumentationKey: monitoring.outputs.instrumentationKey
	}
}

@description('The name of the deployed storage account.')
output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.name

@description('The primary blob endpoint of the storage account.')
output AZURE_STORAGE_BLOB_ENDPOINT string = storage.outputs.primaryBlobEndpoint

@description('The resource ID of the storage account.')
output AZURE_STORAGE_ACCOUNT_ID string = storage.outputs.id

@description('The name of the deployed Function App.')
output AZURE_FUNCTION_APP_NAME string = functionApp.outputs.name

@description('The default hostname of the Function App.')
output AZURE_FUNCTION_APP_HOSTNAME string = functionApp.outputs.defaultHostName

@description('The gateway URL of the API Management instance.')
output AZURE_APIM_GATEWAY_URL string = apim.outputs.gatewayUrl

@description('The name of the Key Vault.')
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name

@description('The URI of the Key Vault.')
output AZURE_KEY_VAULT_URI string = keyVault.outputs.vaultUri

@description('The name of the resource group.')
output AZURE_RESOURCE_GROUP string = resourceGroup.name

@description('The name of the Application Insights instance.')
output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.name

@description('The connection string of the Application Insights instance.')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString

@description('The name of the Log Analytics Workspace.')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.logAnalyticsWorkspaceName
