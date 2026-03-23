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
        services.AddSingleton(_ => new BlobServiceClient(
            new Uri(Environment.GetEnvironmentVariable("AZURE_STORAGE_BLOB_ENDPOINT")!),
            new DefaultAzureCredential()));
        services.AddSingleton<ISasUrlService, SasUrlService>();
    })
    .Build();

await host.RunAsync();
