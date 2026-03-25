// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text;
using System.Text.Json;
using Api.Data;
using Api.Functions;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Api.Tests.Functions;

public sealed class CloudflareWebhookTests : IDisposable
{
    private readonly Mock<IWebhookSignatureService> _mockSignatureService;
    private readonly Mock<ILogger<CloudflareWebhook>> _mockLogger;
    private readonly SqliteConnection _connection;
    private readonly StandupDbContext _dbContext;
    private readonly CloudflareWebhook _function;

    public CloudflareWebhookTests()
    {
        _mockSignatureService = new Mock<IWebhookSignatureService>();
        _mockLogger = new Mock<ILogger<CloudflareWebhook>>();

        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<StandupDbContext>()
            .UseSqlite(_connection)
            .Options;
        _dbContext = new StandupDbContext(options);
        _dbContext.Database.EnsureCreated();

        var mockFactory = new Mock<IDbContextFactory<StandupDbContext>>();
        mockFactory.Setup(f => f.CreateDbContextAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(() => new StandupDbContext(options));

        _function = new CloudflareWebhook(
            _mockLogger.Object,
            mockFactory.Object,
            _mockSignatureService.Object);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
        _connection.Dispose();
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

    [Fact]
    public async Task RunAsync_ReadyWebhook_LooksUpVideoByMetaVideoId()
    {
        var videoId = Guid.NewGuid();
        const string cloudflareUid = "cf-uid-meta-lookup";
        _dbContext.Videos.Add(new Video
        {
            Id = videoId,
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/meta-lookup.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 1_000_000,
            Status = VideoStatus.Processing,
            CloudflareVideoUid = cloudflareUid,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        var payload = BuildReadyPayload(cloudflareUid, meta: new { videoId = videoId.ToString() });
        var request = BuildRequest(JsonSerializer.Serialize(payload), "time=1741500000,sig1=fakesig");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<OkResult>(result);
        var videoForReload = await _dbContext.Videos.FindAsync(videoId);
        await _dbContext.Entry(videoForReload!).ReloadAsync();
        var video = await _dbContext.Videos.FindAsync(videoId);
        Assert.NotNull(video);
        Assert.Equal(VideoStatus.Ready, video.Status);
    }

    [Fact]
    public async Task RunAsync_ReadyWebhook_FallsBackToCloudflareVideoUid()
    {
        var videoId = Guid.NewGuid();
        const string cloudflareUid = "cf-uid-fallback";
        _dbContext.Videos.Add(new Video
        {
            Id = videoId,
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/fallback.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 1_000_000,
            Status = VideoStatus.Processing,
            CloudflareVideoUid = cloudflareUid,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        // No meta.videoId — fallback to uid lookup
        var payload = new
        {
            uid = cloudflareUid,
            readyToStream = true,
            status = new { state = "ready" },
            playback = new { hls = "https://example.com/hls/manifest.m3u8", dash = "https://example.com/dash/manifest.mpd" },
            thumbnail = "https://example.com/thumb.jpg",
            duration = 30.0,
            input = new { width = 1280, height = 720 }
        };
        var request = BuildRequest(JsonSerializer.Serialize(payload), "time=1741500000,sig1=fakesig");

        var result = await _function.RunAsync(request, CancellationToken.None);

        Assert.IsType<OkResult>(result);
        var videoForReload = await _dbContext.Videos.FindAsync(videoId);
        await _dbContext.Entry(videoForReload!).ReloadAsync();
        var video = await _dbContext.Videos.FindAsync(videoId);
        Assert.NotNull(video);
        Assert.Equal(VideoStatus.Ready, video.Status);
    }

    [Fact]
    public async Task RunAsync_ReadyWebhook_SetsUrlsAndDurationAndDimensionsAndStatusReady()
    {
        var videoId = Guid.NewGuid();
        const string cloudflareUid = "cf-uid-ready-full";
        _dbContext.Videos.Add(new Video
        {
            Id = videoId,
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/ready-full.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Processing,
            CloudflareVideoUid = cloudflareUid,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        const string hlsUrl = "https://customer.cloudflarestream.com/cf-uid-ready-full/manifest/video.m3u8";
        const string dashUrl = "https://customer.cloudflarestream.com/cf-uid-ready-full/manifest/video.mpd";
        const string thumbnailUrl = "https://customer.cloudflarestream.com/cf-uid-ready-full/thumbnails/thumbnail.jpg";
        var payload = new
        {
            uid = cloudflareUid,
            readyToStream = true,
            status = new { state = "ready" },
            playback = new { hls = hlsUrl, dash = dashUrl },
            thumbnail = thumbnailUrl,
            duration = 95.5,
            input = new { width = 1920, height = 1080 }
        };
        var request = BuildRequest(JsonSerializer.Serialize(payload), "time=1741500000,sig1=fakesig");

        await _function.RunAsync(request, CancellationToken.None);

        var videoForReload = await _dbContext.Videos.FindAsync(videoId);
        await _dbContext.Entry(videoForReload!).ReloadAsync();
        var video = await _dbContext.Videos.FindAsync(videoId);
        Assert.NotNull(video);
        Assert.Equal(VideoStatus.Ready, video.Status);
        Assert.Equal(hlsUrl, video.HlsUrl);
        Assert.Equal(dashUrl, video.DashUrl);
        Assert.Equal(thumbnailUrl, video.ThumbnailUrl);
        Assert.Equal(95.5, video.Duration);
        Assert.Equal(1920, video.InputWidth);
        Assert.Equal(1080, video.InputHeight);
    }

    [Fact]
    public async Task RunAsync_ErrorWebhook_SetsErrorReasonCodeAndTextAndStatusFailed()
    {
        var videoId = Guid.NewGuid();
        const string cloudflareUid = "cf-uid-error";
        _dbContext.Videos.Add(new Video
        {
            Id = videoId,
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/error-video.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 3_000_000,
            Status = VideoStatus.Processing,
            CloudflareVideoUid = cloudflareUid,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        _mockSignatureService
            .Setup(s => s.VerifySignature(It.IsAny<string?>(), It.IsAny<string>()))
            .Returns(true);

        var payload = new
        {
            uid = cloudflareUid,
            readyToStream = false,
            status = new
            {
                state = "error",
                errorReasonCode = "ERR_NON_VIDEO",
                errorReasonText = "File is not a video"
            }
        };
        var request = BuildRequest(JsonSerializer.Serialize(payload), "time=1741500000,sig1=fakesig");

        await _function.RunAsync(request, CancellationToken.None);

        var videoForReload = await _dbContext.Videos.FindAsync(videoId);
        await _dbContext.Entry(videoForReload!).ReloadAsync();
        var video = await _dbContext.Videos.FindAsync(videoId);
        Assert.NotNull(video);
        Assert.Equal(VideoStatus.Failed, video.Status);
        Assert.Equal("ERR_NON_VIDEO", video.ErrorReasonCode);
        Assert.Equal("File is not a video", video.ErrorReasonText);
    }

    private static object BuildReadyPayload(string uid, object? meta = null) => new
    {
        uid,
        readyToStream = true,
        status = new { state = "ready" },
        playback = new { hls = $"https://example.com/{uid}/hls.m3u8", dash = $"https://example.com/{uid}/dash.mpd" },
        thumbnail = $"https://example.com/{uid}/thumb.jpg",
        duration = 60.0,
        input = new { width = 1280, height = 720 },
        meta
    };

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
