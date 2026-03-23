// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the Key Vault.')
param name string

@description('The Azure region in which to deploy the Key Vault.')
param location string

@description('Tags to apply to the Key Vault.')
param tags object = {}

@description('The principal ID of the Function App managed identity, granted Key Vault Secrets Officer role.')
param functionAppPrincipalId string

@description('The principal ID of the APIM managed identity, granted Key Vault Secrets User role.')
param apimPrincipalId string

@description('The resource ID of the Log Analytics Workspace for diagnostic settings.')
param logAnalyticsWorkspaceId string

// Key Vault Secrets Officer role — allows the Function App to set the host key secret
var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

// Key Vault Secrets User role — allows APIM to read the host key secret
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
	name: name
	location: location
	tags: tags
	properties: {
		sku: {
			family: 'A'
			name: 'standard'
		}
		tenantId: subscription().tenantId
		enableRbacAuthorization: true
		enableSoftDelete: true
		softDeleteRetentionInDays: 7
	}
}

resource functionAppSecretsOfficerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(keyVault.id, functionAppPrincipalId, keyVaultSecretsOfficerRoleId)
	scope: keyVault
	properties: {
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleId)
		principalId: functionAppPrincipalId
		principalType: 'ServicePrincipal'
	}
}

resource apimSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: guid(keyVault.id, apimPrincipalId, keyVaultSecretsUserRoleId)
	scope: keyVault
	properties: {
		roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
		principalId: apimPrincipalId
		principalType: 'ServicePrincipal'
	}
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
	name: 'key-vault-diagnostics'
	scope: keyVault
	properties: {
		workspaceId: logAnalyticsWorkspaceId
		logs: [
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

@description('The resource ID of the Key Vault.')
output id string = keyVault.id

@description('The name of the Key Vault.')
output name string = keyVault.name

@description('The URI of the Key Vault.')
output vaultUri string = keyVault.properties.vaultUri
