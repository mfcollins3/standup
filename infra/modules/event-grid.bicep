// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the storage account used as the Event Grid source.')
param storageAccountName string

@description('The resource ID of the storage account used as the Event Grid source.')
param storageAccountId string

@description('The Azure region in which to deploy Event Grid resources.')
param location string

@description('Tags to apply to Event Grid resources.')
param tags object = {}

@description('The default hostname of the Function App webhook target.')
param functionAppHostName string

@description('The resource ID of the Function App.')
param functionAppId string

@description('Whether to deploy Event Grid resources. Set to false for initial deployment, true after the Function App is running.')
param enableEventGrid bool = false

resource eventGridSystemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = if (enableEventGrid) {
	name: '${storageAccountName}-evgt'
	location: location
	tags: tags
	properties: {
		source: storageAccountId
		topicType: 'Microsoft.Storage.StorageAccounts'
	}
}

var eventGridSystemKey = enableEventGrid
	? listKeys('${functionAppId}/host/default', '2024-04-01').systemKeys.eventgrid_extension
	: ''

resource blobCreatedSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = if (enableEventGrid) {
	parent: eventGridSystemTopic
	name: '${storageAccountName}-evgs'
	properties: {
		filter: {
			subjectBeginsWith: '/blobServices/default/containers/status-videos/blobs/uploads/'
			includedEventTypes: [
				'Microsoft.Storage.BlobCreated'
			]
		}
		destination: {
			endpointType: 'WebHook'
			properties: {
				endpointUrl: 'https://${functionAppHostName}/runtime/webhooks/eventgrid?functionName=ProcessVideo&code=${eventGridSystemKey}'
			}
		}
		deadLetterDestination: {
			endpointType: 'StorageBlob'
			properties: {
				resourceId: storageAccountId
				blobContainerName: 'status-videos'
				blobPrefix: 'deadletter/'
			}
		}
		retryPolicy: {
			maxDeliveryAttempts: 30
			eventTimeToLiveInMinutes: 1440
		}
	}
}
