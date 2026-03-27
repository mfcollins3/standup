// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the API Management instance.')
param name string

@description('The Azure region in which to deploy API Management.')
param location string

@description('Tags to apply to resources.')
param tags object = {}

@description('The URL of the Function App backend.')
param functionAppUrl string

@description('The host key of the Function App, used by APIM to authenticate to the backend.')
@secure()
param functionKey string

@description('The publisher email address for the APIM instance.')
param publisherEmail string

@description('The publisher name for the APIM instance.')
param publisherName string

@description('The resource ID of the Application Insights instance.')
param appInsightsId string

@description('The instrumentation key of the Application Insights instance.')
@secure()
param appInsightsInstrumentationKey string

resource apimService 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
	name: name
	location: location
	tags: tags
	sku: {
		name: 'Consumption'
		capacity: 0
	}
	identity: {
		type: 'SystemAssigned'
	}
	properties: {
		publisherEmail: publisherEmail
		publisherName: publisherName
	}
}

resource functionKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
	parent: apimService
	name: 'function-app-host-key'
	properties: {
		displayName: 'function-app-host-key'
		value: functionKey
		secret: true
	}
}

resource functionAppBackend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
	parent: apimService
	name: 'standup-api-backend'
	dependsOn: [functionKeyNamedValue]
	properties: {
		description: 'Standup API Function App backend'
		url: 'https://${functionAppUrl}/api'
		protocol: 'http'
		credentials: {
			header: {
				'x-functions-key': [
					'{{function-app-host-key}}'
				]
			}
		}
	}
}

resource standupApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
	parent: apimService
	name: 'standup-api'
	properties: {
		displayName: 'Standup API'
		description: 'API for the Naked Standup platform'
		path: 'standup'
		protocols: [
			'https'
		]
		subscriptionRequired: true
		subscriptionKeyParameterNames: {
			header: 'X-Api-Key'
		}
	}
}

resource createVideoOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
	parent: standupApi
	name: 'create-video'
	properties: {
		displayName: 'Create Video'
		description: 'Request a SAS URL for uploading a status video to Azure Blob Storage.'
		method: 'POST'
		urlTemplate: '/video'
		request: {
			representations: [
				{
					contentType: 'application/json'
				}
			]
		}
		responses: [
			{
				statusCode: 200
				description: 'SAS URL generated successfully'
			}
			{
				statusCode: 400
				description: 'Bad request'
			}
			{
				statusCode: 401
				description: 'Unauthorized'
			}
			{
				statusCode: 415
				description: 'Unsupported media type'
			}
		]
	}
}

resource getSignedStreamUrlOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
	parent: standupApi
	name: 'get-signed-stream-url'
	properties: {
		displayName: 'Get Signed Stream URL'
		description: 'Request a signed HLS or DASH manifest URL for streaming a transcoded video via Cloudflare Stream.'
		method: 'GET'
		urlTemplate: '/video/{videoId}/stream'
		templateParameters: [
			{
				name: 'videoId'
				description: 'The unique identifier of the video.'
				type: 'string'
				required: true
			}
		]
		request: {
			queryParameters: [
				{
					name: 'streamType'
					description: 'The desired stream format. Must be either "hls" or "dash".'
					type: 'string'
					required: true
				}
			]
		}
		responses: [
			{
				statusCode: 200
				description: 'Signed manifest URL generated successfully'
				representations: [
					{
						contentType: 'application/json'
					}
				]
			}
			{
				statusCode: 400
				description: 'Bad request — invalid or missing streamType parameter'
			}
			{
				statusCode: 401
				description: 'Unauthorized'
			}
			{
				statusCode: 404
				description: 'Video not found'
			}
			{
				statusCode: 409
				description: 'Video is not yet ready for streaming'
			}
		]
	}
}

resource standupApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {	parent: standupApi
	name: 'policy'
	dependsOn: [functionAppBackend, functionKeyNamedValue]
	properties: {
		format: 'xml'
		value: '''
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="standup-api-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
	}
}

resource standupApiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
	parent: apimService
	name: 'standup-ios-client'
	properties: {
		displayName: 'Standup iOS Client'
		scope: standupApi.id
		state: 'active'
	}
}

resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
	parent: apimService
	name: 'applicationinsights-logger'
	properties: {
		loggerType: 'applicationInsights'
		description: 'Application Insights logger'
		credentials: {
			instrumentationKey: appInsightsInstrumentationKey
		}
		isBuffered: true
		resourceId: appInsightsId
	}
}

resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-09-01-preview' = {
	parent: apimService
	name: 'applicationinsights'
	properties: {
		alwaysLog: 'allErrors'
		loggerId: appInsightsLogger.id
		logClientIp: true
		sampling: {
			samplingType: 'fixed'
			percentage: 100
		}
		frontend: {
			request: {
				headers: []
				body: {
					bytes: 0
				}
			}
			response: {
				headers: []
				body: {
					bytes: 0
				}
			}
		}
		backend: {
			request: {
				headers: []
				body: {
					bytes: 0
				}
			}
			response: {
				headers: []
				body: {
					bytes: 0
				}
			}
		}
	}
}

@description('The resource ID of the API Management instance.')
output id string = apimService.id

@description('The gateway URL for the API Management instance.')
output gatewayUrl string = apimService.properties.gatewayUrl

@description('The principal ID of the APIM managed identity.')
output principalId string = apimService.identity.principalId
