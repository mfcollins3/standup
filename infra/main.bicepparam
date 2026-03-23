// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param publisherEmail = readEnvironmentVariable('AZURE_PUBLISHER_EMAIL', 'support@nakedstandup.app')
param publisherName = readEnvironmentVariable('AZURE_PUBLISHER_NAME', 'Naked Standup')
