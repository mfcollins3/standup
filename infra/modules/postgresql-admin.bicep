// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the existing PostgreSQL Flexible Server.')
param serverName string

@description('The principal ID of the Function App managed identity for Entra admin access.')
param functionAppPrincipalId string

@description('The display name of the Function App managed identity for Entra admin.')
param functionAppPrincipalName string

// Reference the already-deployed server. This module is intentionally separate from
// the server module so that main.bicep can impose an explicit dependsOn, ensuring the
// server has returned to a "Ready" state before the Entra admin operation is attempted.
resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' existing = {
  name: serverName
}

resource aadAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  parent: server
  name: functionAppPrincipalId
  properties: {
    principalType: 'ServicePrincipal'
    principalName: functionAppPrincipalName
    tenantId: tenant().tenantId
  }
}
