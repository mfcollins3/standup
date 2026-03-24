// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Net;
using System.Net.Http.Json;
using Api.Models;
using Microsoft.Extensions.Configuration;

namespace Api.Services;

public sealed class CloudflareStreamService(
    HttpClient httpClient,
    IConfiguration configuration) : ICloudflareStreamService
{
    private readonly string _accountId = configuration["CLOUDFLARE_ACCOUNT_ID"]
        ?? throw new InvalidOperationException("CLOUDFLARE_ACCOUNT_ID is not configured.");
    private readonly string _apiToken = configuration["CLOUDFLARE_API_TOKEN"]
        ?? throw new InvalidOperationException("CLOUDFLARE_API_TOKEN is not configured.");

    public async Task<CloudflareStreamResponse> SubmitForTranscodingAsync(
        Uri videoReadUrl,
        string blobPath,
        CancellationToken cancellationToken = default)
    {
        var request = new CloudflareStreamRequest(
            Url: videoReadUrl.ToString(),
            Meta: new Dictionary<string, string> { ["blobPath"] = blobPath });

        using var httpRequest = new HttpRequestMessage(
            HttpMethod.Post,
            $"accounts/{_accountId}/stream/copy");
        httpRequest.Headers.Add("Authorization", $"Bearer {_apiToken}");
        httpRequest.Content = JsonContent.Create(request);

        var response = await httpClient.SendAsync(httpRequest, cancellationToken);

        if (response.StatusCode == HttpStatusCode.TooManyRequests ||
            (int)response.StatusCode >= 500)
        {
            throw new HttpRequestException(
                $"Transient error from Cloudflare Stream: {(int)response.StatusCode}",
                null,
                response.StatusCode);
        }

        if (response.StatusCode == HttpStatusCode.BadRequest ||
            response.StatusCode == HttpStatusCode.Unauthorized)
        {
            var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
            throw new CloudflareStreamPermanentException(
                $"Permanent error from Cloudflare Stream ({(int)response.StatusCode}): {errorBody}");
        }

        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<CloudflareStreamResponse>(
            cancellationToken: cancellationToken);
        return result!;
    }
}

public sealed class CloudflareStreamPermanentException : Exception
{
    public CloudflareStreamPermanentException(string message) : base(message) { }

    public CloudflareStreamPermanentException(string message, Exception inner)
        : base(message, inner) { }
}
