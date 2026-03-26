// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the PostgreSQL Flexible Server.')
param name string

@description('The Azure region where the server will be deployed.')
param location string

@description('Tags to apply to the server resource.')
param tags object

@description('The name of the database to create on the server.')
param databaseName string = 'standup'

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '17'
    storage: {
      storageSizeGB: 32
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: subscription().tenantId
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }

  // Allows traffic originating from within Azure's infrastructure (e.g. Function Apps,
  // App Services). This is Azure's sentinel value — 0.0.0.0/0.0.0.0 does NOT open the
  // server to the public internet; it only permits Azure-hosted services.
  resource allowAzureServices 'firewallRules' = {
    name: 'AllowAllAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource database 'databases' = {
    name: databaseName
    properties: {
      charset: 'UTF8'
      collation: 'en_US.utf8'
    }
  }
}

@description('The fully qualified domain name of the PostgreSQL server.')
output fullyQualifiedDomainName string = server.properties.fullyQualifiedDomainName

@description('The name of the PostgreSQL server.')
output serverName string = server.name
