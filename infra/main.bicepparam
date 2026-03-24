// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using './main.bicep'

param cloudflareAccountId = readEnvironmentVariable('CLOUDFLARE_ACCOUNT_ID')
param cloudflareApiToken = readEnvironmentVariable('CLOUDFLARE_API_TOKEN')
param cloudflareWebhookSigningSecret = readEnvironmentVariable('CLOUDFLARE_WEBHOOK_SIGNING_SECRET')
param environmentName = readEnvironmentVariable('AZURE_ENV_NAME')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')
param publisherEmail = readEnvironmentVariable('AZURE_PUBLISHER_EMAIL', 'support@nakedstandup.app')
param publisherName = readEnvironmentVariable('AZURE_PUBLISHER_NAME', 'Naked Standup')
param enableEventGrid = readEnvironmentVariable('ENABLE_EVENT_GRID', 'false') == 'true'
