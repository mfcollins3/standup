// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Services;
using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services =>
    {
        services.AddSingleton(_ =>
        {
            var blobEndpoint = Environment.GetEnvironmentVariable("AZURE_STORAGE_BLOB_ENDPOINT")
                ?? throw new InvalidOperationException(
                    "Required configuration setting 'AZURE_STORAGE_BLOB_ENDPOINT' is missing. " +
                    "Ensure this environment variable is set in the Function App configuration.");
            return new BlobServiceClient(new Uri(blobEndpoint), new DefaultAzureCredential());
        });
        services.AddSingleton<ISasUrlService, SasUrlService>();
    })
    .Build();

await host.RunAsync();
