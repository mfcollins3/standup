// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Net;
using System.Text.Json;
using Api.Models;
using Api.Services;
using Microsoft.Extensions.Configuration;
using Moq;
using Moq.Protected;
using Xunit;

namespace Api.Tests.Services;

public sealed class CloudflareStreamServiceTests
{
    private const string FakeAccountId = "test-account-id";
    private const string FakeApiToken = "test-api-token";

    private static (CloudflareStreamService Service, Mock<HttpMessageHandler> Handler)
        BuildService(HttpStatusCode statusCode = HttpStatusCode.OK,
                     string? responseBody = null)
    {
        var defaultResponse = new CloudflareStreamResponse(
            Success: true,
            Result: new CloudflareStreamResult(
                Uid: "cf-uid-123",
                ReadyToStream: false,
                Status: new CloudflareStreamStatus("queued", null, null, null),
                Playback: null),
            Errors: [],
            Messages: []);

        var responseJson = responseBody
            ?? JsonSerializer.Serialize(defaultResponse);

        var handler = new Mock<HttpMessageHandler>();
        handler
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(new HttpResponseMessage
            {
                StatusCode = statusCode,
                Content = new StringContent(responseJson)
            });

        var httpClient = new HttpClient(handler.Object)
        {
            BaseAddress = new Uri("https://api.cloudflare.com/client/v4/")
        };

        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_ACCOUNT_ID"] = FakeAccountId,
                ["CLOUDFLARE_API_TOKEN"] = FakeApiToken
            })
            .Build();

        var service = new CloudflareStreamService(httpClient, configuration);
        return (service, handler);
    }

    [Fact]
    public async Task SubmitForTranscodingAsync_AlwaysSetsRequireSignedUrlsTrue()
    {
        // Arrange
        string? capturedRequestBody = null;
        var handler = new Mock<HttpMessageHandler>();
        handler
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Returns<HttpRequestMessage, CancellationToken>(async (req, ct) =>
            {
                // Read the body before it can be disposed
                capturedRequestBody = await req.Content!.ReadAsStringAsync(ct);
                return new HttpResponseMessage
                {
                    StatusCode = HttpStatusCode.OK,
                    Content = new StringContent(JsonSerializer.Serialize(new CloudflareStreamResponse(
                        Success: true,
                        Result: new CloudflareStreamResult(
                            Uid: "cf-uid-123",
                            ReadyToStream: false,
                            Status: new CloudflareStreamStatus("queued", null, null, null),
                            Playback: null),
                        Errors: [],
                        Messages: [])))
                };
            });

        var httpClient = new HttpClient(handler.Object)
        {
            BaseAddress = new Uri("https://api.cloudflare.com/client/v4/")
        };

        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_ACCOUNT_ID"] = FakeAccountId,
                ["CLOUDFLARE_API_TOKEN"] = FakeApiToken
            })
            .Build();

        var service = new CloudflareStreamService(httpClient, configuration);

        // Act
        await service.SubmitForTranscodingAsync(
            new Uri("https://example.com/video.mp4"),
            Guid.NewGuid(),
            "uploads/video.mp4");

        // Assert
        Assert.NotNull(capturedRequestBody);
        using var doc = JsonDocument.Parse(capturedRequestBody!);

        Assert.True(
            doc.RootElement.TryGetProperty("requireSignedURLs", out var requireSignedUrlsElement),
            "Request body should contain 'requireSignedURLs' property.");
        Assert.True(
            requireSignedUrlsElement.GetBoolean(),
            "requireSignedURLs should be true.");
    }

    [Fact]
    public async Task SubmitForTranscodingAsync_SuccessResponse_ReturnsResult()
    {
        var (service, _) = BuildService();
        var videoUri = new Uri("https://example.com/video.mp4");

        var result = await service.SubmitForTranscodingAsync(videoUri, null, "uploads/video.mp4");

        Assert.True(result.Success);
        Assert.Equal("cf-uid-123", result.Result?.Uid);
    }
}
