// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the Function App.')
param name string

@description('The name of the App Service Plan (Consumption).')
param planName string

@description('The Azure region in which to deploy resources.')
param location string

@description('Tags to apply to resources.')
param tags object = {}

@description('The resource ID of the video storage account.')
param storageAccountId string

@description('The name of the video storage account.')
param storageAccountName string

@description('The primary blob endpoint of the video storage account.')
param storageAccountBlobEndpoint string

// Storage Blob Delegator role — allows GetUserDelegationKey
var storageBlobDelegatorRoleId = 'db58b8e5-c6ad-4a2a-8342-4190687cbf4a'

// Storage Blob Data Contributor role — allows generating SAS tokens for blob write access
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
	name: planName
	location: location
	tags: tags
	kind: 'functionapp'
	sku: {
		name: 'Y1'
		tier: 'Dynamic'
	}
	properties: {
		reserved: true
	}
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
	name: name
	location: location
	tags: union(tags, {
		'azd-service-name': 'api'
	})
	kind: 'functionapp,linux'
	identity: {
		type: 'SystemAssigned'
	}
	properties: {
		serverFarmId: appServicePlan.id
		httpsOnly: true
		siteConfig: {
			linuxFxVersion: 'DOTNET-ISOLATED|10.0'
			functionAppScaleLimit: 200
			appSettings: [
				{
					name: 'AzureWebJobsStorage__accountName'
					value: storageAccountName
				}
				{
					name: 'FUNCTIONS_EXTENSION_VERSION'
					value: '~4'
				}
				{
					name: 'FUNCTIONS_WORKER_RUNTIME'
					value: 'dotnet-isolated'
				}
				{
					name: 'AZURE_STORAGE_BLOB_ENDPOINT'
					value: storageAccountBlobEndpoint
				}
			]
		}
	}
}

resource storageBlobDelegatorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(storageAccountId, functionApp.id, storageBlobDelegatorRoleId)
	scope: resourceGroup()
	properties: {
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDelegatorRoleId)
		principalId: functionApp.identity.principalId
		principalType: 'ServicePrincipal'
	}
}

resource storageBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(storageAccountId, functionApp.id, storageBlobDataContributorRoleId)
	scope: resourceGroup()
	properties: {
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
		principalId: functionApp.identity.principalId
		principalType: 'ServicePrincipal'
	}
}

@description('The resource ID of the Function App.')
output id string = functionApp.id

@description('The name of the Function App.')
output name string = functionApp.name

@description('The principal ID of the Function App managed identity.')
output principalId string = functionApp.identity.principalId

@description('The default hostname of the Function App.')
output defaultHostName string = functionApp.properties.defaultHostName
