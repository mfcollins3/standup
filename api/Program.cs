// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Data;
using Api.Services;
using Azure.Core;
using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Npgsql;

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
        services.AddSingleton<IWebhookSignatureService, WebhookSignatureService>();
        services.AddHttpClient<ICloudflareStreamService, CloudflareStreamService>(client =>
        {
            client.BaseAddress = new Uri("https://api.cloudflare.com/client/v4/");
        });

        var postgresqlHost = Environment.GetEnvironmentVariable("POSTGRESQL_HOST")
            ?? throw new InvalidOperationException(
                "Required configuration setting 'POSTGRESQL_HOST' is missing. " +
                "Ensure this environment variable is set in the Function App configuration.");
        var postgresqlDatabase = Environment.GetEnvironmentVariable("POSTGRESQL_DATABASE")
            ?? throw new InvalidOperationException(
                "Required configuration setting 'POSTGRESQL_DATABASE' is missing. " +
                "Ensure this environment variable is set in the Function App configuration.");
        var postgresqlUsername = Environment.GetEnvironmentVariable("POSTGRESQL_USERNAME")
            ?? throw new InvalidOperationException(
                "Required configuration setting 'POSTGRESQL_USERNAME' is missing. " +
                "Ensure this environment variable is set in the Function App configuration.");

        var connectionString = $"Host={postgresqlHost};Database={postgresqlDatabase};" +
            $"Username={postgresqlUsername};Ssl Mode=Require;Trust Server Certificate=true";

        var credential = new DefaultAzureCredential();
        var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
        dataSourceBuilder.UsePeriodicPasswordProvider(
            async (_, ct) =>
            {
                var tokenRequest = new TokenRequestContext(
                    new[] { "https://ossrdbms-aad.database.windows.net/.default" });
                var token = await credential.GetTokenAsync(tokenRequest, ct);
                return token.Token;
            },
            TimeSpan.FromMinutes(55),
            TimeSpan.Zero);
        var dataSource = dataSourceBuilder.Build();

        services.AddSingleton(dataSource);
        services.AddDbContextFactory<StandupDbContext>(options =>
            options.UseNpgsql(dataSource));
    })
    .Build();

// Note: Database migrations are intentionally not executed at Function host startup.
// In Azure Functions, running EF Core migrations at startup can cause race conditions
// and increase cold-start latency when multiple instances start concurrently.
// Apply migrations out-of-band (e.g., via CI/CD pipeline or a dedicated migration job)
// before deploying or scaling this Function App.

await host.RunAsync();
