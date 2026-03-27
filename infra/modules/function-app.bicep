// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the Function App.')
param name string

@description('The name of the App Service Plan (Flex Consumption).')
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

@description('The connection string for the Application Insights instance.')
param appInsightsConnectionString string

@description('The name of the Key Vault containing Cloudflare credentials.')
param keyVaultName string

@description('The Cloudflare customer code used to construct signed manifest URLs for streaming.')
param cloudflareCustomerCode string = ''

@description('The fully qualified domain name of the PostgreSQL Flexible Server.')
param postgresqlHost string

@description('The name of the PostgreSQL database.')
param postgresqlDatabase string = 'standup'

@description('The PostgreSQL username (the managed identity name used for Entra auth).')
param postgresqlUsername string

// Storage Blob Delegator role — allows GetUserDelegationKey
var storageBlobDelegatorRoleId = 'db58b8e5-c6ad-4a2a-8342-4190687cbf4a'

// Storage Blob Data Contributor role — allows generating SAS tokens for blob write access
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// Storage Blob Data Owner role — required by Flex Consumption for deployment package storage access
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
	name: storageAccountName

	resource blobService 'blobServices' existing = {
		name: 'default'
	}
}

// Container for the function app deployment package
resource deploymentPackageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
	name: 'deploymentpackage'
	parent: storageAccount::blobService
	properties: {
		publicAccess: 'None'
	}
}

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
	name: planName
	location: location
	tags: tags
	kind: 'functionapp'
	sku: {
		name: 'FC1'
		tier: 'FlexConsumption'
	}
	properties: {
		reserved: true
	}
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
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
					name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
					value: appInsightsConnectionString
				}
				{
					name: 'AZURE_STORAGE_BLOB_ENDPOINT'
					value: storageAccountBlobEndpoint
				}
				{
					name: 'CLOUDFLARE_ACCOUNT_ID'
					value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=CloudflareAccountId)'
				}
				{
					name: 'CLOUDFLARE_API_TOKEN'
					value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=CloudflareApiToken)'
				}
				{
					name: 'CLOUDFLARE_WEBHOOK_SIGNING_SECRET'
					value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=CloudflareWebhookSigningSecret)'
				}
				{
					name: 'CLOUDFLARE_SIGNING_KEY_ID'
					value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=CloudflareSigningKeyId)'
				}
				{
					name: 'CLOUDFLARE_SIGNING_KEY_JWK'
					value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=CloudflareSigningKeyJwk)'
				}
				{
					name: 'CLOUDFLARE_CUSTOMER_CODE'
					value: cloudflareCustomerCode
				}
				{
					name: 'POSTGRESQL_HOST'
					value: postgresqlHost
				}
				{
					name: 'POSTGRESQL_DATABASE'
					value: postgresqlDatabase
				}
				{
					name: 'POSTGRESQL_USERNAME'
					value: postgresqlUsername
				}
			]
		}
		functionAppConfig: {
			deployment: {
				storage: {
					type: 'blobContainer'
					value: '${storageAccountBlobEndpoint}${deploymentPackageContainer.name}'
					authentication: {
						type: 'SystemAssignedIdentity'
					}
				}
			}
			scaleAndConcurrency: {
				maximumInstanceCount: 200
				instanceMemoryMB: 2048
			}
			runtime: {
				name: 'dotnet-isolated'
				version: '10.0'
			}
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

// Storage Blob Data Owner is required for Flex Consumption deployment package storage access
resource storageBlobDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(storageAccountId, functionApp.id, storageBlobDataOwnerRoleId)
	scope: resourceGroup()
	properties: {
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
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

@description('The default host key of the Function App.')
output hostKey string = listKeys('${functionApp.id}/host/default', '2024-04-01').functionKeys.default
