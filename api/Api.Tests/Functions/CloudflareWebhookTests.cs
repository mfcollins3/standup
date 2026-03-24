// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text;
using System.Text.Json;
using Api.Functions;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Api.Tests.Functions;

public sealed class CloudflareWebhookTests
{
    private readonly Mock<IWebhookSignatureService> _mockSignatureService;
    private readonly Mock<ILogger<CloudflareWebhook>> _mockLogger;
    private readonly CloudflareWebhook _function;

    public CloudflareWebhookTests()
    {
        _mockSignatureService = new Mock<IWebhookSignatureService>();
        _mockLogger = new Mock<ILogger<CloudflareWebhook>>();
        _function = new CloudflareWebhook(
            _mockLogger.Object,
            _mockSignatureService.Object);
    }

    [Fact]
    public async Task RunAsync_ValidSignatureSuccessPayload_Returns200AndLogsReadyStatus()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        const string uid = "abc123def456";
        var payload = new
        {
            uid,
            readyToStream = true,
            status = new { state = "ready" },
            duration = 120.5,
            size = 1_048_576
        };
        var request = BuildRequest(
            JsonSerializer.Serialize(payload),
            "time=1741500000,sig1=fakesig");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<OkResult>(result);
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(uid)),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce());
    }

    [Fact]
    public async Task RunAsync_ValidSignatureErrorPayload_Returns200AndLogsErrorDetails()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        const string uid = "vid999error";
        var payload = new
        {
            uid,
            readyToStream = false,
            status = new
            {
                state = "error",
                errorReasonCode = "ERR_NON_VIDEO",
                errorReasonText = "File is not a video"
            }
        };
        var request = BuildRequest(
            JsonSerializer.Serialize(payload),
            "time=1741500000,sig1=fakesig");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<OkResult>(result);
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(uid)),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce());
    }

    [Fact]
    public async Task RunAsync_MissingSignatureHeader_Returns401()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(false);

        var request = BuildRequest(
            """{"uid":"test123","readyToStream":true}""",
            signatureHeader: null);

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_InvalidSignature_Returns401()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(false);

        var request = BuildRequest(
            """{"uid":"test456","readyToStream":true}""",
            "time=1741500000,sig1=invalidsignature");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_EmptyBody_Returns400()
    {
        var request = BuildRequest("", signatureHeader: null);

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_MalformedJsonBody_Returns400()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        var request = BuildRequest("not json", "time=1741500000,sig1=fakesig");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_NullUidInPayload_Returns200()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        var request = BuildRequest(
            """{"uid":null,"readyToStream":true,"status":{"state":"ready"}}""",
            "time=1741500000,sig1=fakesig");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<OkResult>(result);
    }

    [Fact]
    public async Task RunAsync_DuplicateNotification_BothReturn200()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        const string body =
            """{"uid":"dupvid123","readyToStream":true,"status":{"state":"ready"}}""";

        var result1 = await _function.RunAsync(
            BuildRequest(body, "time=1741500000,sig1=fakesig"),
            CancellationToken.None);
        var result2 = await _function.RunAsync(
            BuildRequest(body, "time=1741500000,sig1=fakesig"),
            CancellationToken.None);

        Assert.IsType<OkResult>(result1);
        Assert.IsType<OkResult>(result2);
    }

    [Fact]
    public async Task RunAsync_RejectedRequest_LogsWarningWithoutExposingSecret()
    {
        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(false);

        var request = BuildRequest(
            """{"uid":"test789","readyToStream":true}""",
            "time=1741500000,sig1=badsig");

        await _function.RunAsync(request, CancellationToken.None);

        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) =>
                    !v.ToString()!.Contains("secret", StringComparison.OrdinalIgnoreCase)),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce());
    }

    private static HttpRequest BuildRequest(string body, string? signatureHeader)
    {
        var context = new DefaultHttpContext();
        context.Request.Method = "POST";
        context.Request.ContentType = "application/json";
        var bytes = Encoding.UTF8.GetBytes(body);
        context.Request.Body = new MemoryStream(bytes);
        context.Request.ContentLength = bytes.Length;
        if (signatureHeader is not null)
        {
            context.Request.Headers["Webhook-Signature"] = signatureHeader;
        }
        return context.Request;
    }
}
