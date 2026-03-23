// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

@description('The name of the storage account.')
param name string

@description('The Azure region in which to deploy the storage account.')
param location string

@description('Tags to apply to the storage account.')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
	name: name
	location: location
	tags: tags
	kind: 'StorageV2'
	sku: {
		name: 'Standard_LRS'
	}
	properties: {
		accessTier: 'Hot'
		allowBlobPublicAccess: false
		allowSharedKeyAccess: false
		minimumTlsVersion: 'TLS1_2'
		supportsHttpsTrafficOnly: true
	}
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
	parent: storageAccount
	name: 'default'
}

resource statusVideosContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
	parent: blobService
	name: 'status-videos'
	properties: {
		publicAccess: 'None'
	}
}

resource eventGridSystemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
	name: '${name}-evgt'
	location: location
	tags: tags
	properties: {
		source: storageAccount.id
		topicType: 'Microsoft.Storage.StorageAccounts'
	}
}

resource blobCreatedSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
	parent: eventGridSystemTopic
	name: '${name}-evgs'
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
				// Placeholder webhook URL — replace with actual processing function endpoint
				endpointUrl: 'https://placeholder.example.com/api/process-video'
			}
		}
		retryPolicy: {
			maxDeliveryAttempts: 3
			eventTimeToLiveInMinutes: 30
		}
	}
}

@description('The resource ID of the storage account.')
output id string = storageAccount.id

@description('The name of the storage account.')
output name string = storageAccount.name

@description('The primary blob service endpoint of the storage account.')
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
