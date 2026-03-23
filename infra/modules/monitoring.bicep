// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the Application Insights instance.')
param name string

@description('The name of the Log Analytics Workspace.')
param logAnalyticsWorkspaceName string

@description('The Azure region in which to deploy resources.')
param location string

@description('Tags to apply to resources.')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
	name: logAnalyticsWorkspaceName
	location: location
	tags: tags
	properties: {
		sku: {
			name: 'PerGB2018'
		}
		retentionInDays: 30
	}
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
	name: name
	location: location
	tags: tags
	kind: 'web'
	properties: {
		Application_Type: 'web'
		WorkspaceResourceId: logAnalyticsWorkspace.id
	}
}

@description('The resource ID of the Application Insights instance.')
output id string = applicationInsights.id

@description('The name of the Application Insights instance.')
output name string = applicationInsights.name

@description('The connection string for the Application Insights instance.')
output connectionString string = applicationInsights.properties.ConnectionString

@description('The instrumentation key for the Application Insights instance.')
output instrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics Workspace.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
