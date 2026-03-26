// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Azure.Messaging.EventGrid;
using Azure.Messaging.EventGrid.SystemEvents;
using Api.Data;
using Api.Functions;
using Api.Models;
using Api.Services;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Api.Tests.Functions;

public sealed class ProcessVideoTests : IDisposable
{
    private static readonly Uri FakeReadSasUri = new(
        "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4?sv=2025-01-05&se=...&sp=r&spr=https&sig=...");

    private readonly Mock<ILogger<ProcessVideo>> _mockLogger;
    private readonly Mock<ISasUrlService> _mockSasService;
    private readonly Mock<ICloudflareStreamService> _mockCloudflareService;
    private readonly SqliteConnection _connection;
    private readonly StandupDbContext _dbContext;
    private readonly ProcessVideo _function;

    public ProcessVideoTests()
    {
        _mockLogger = new Mock<ILogger<ProcessVideo>>();
        _mockSasService = new Mock<ISasUrlService>();
        _mockCloudflareService = new Mock<ICloudflareStreamService>();

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

        _function = new ProcessVideo(
            _mockLogger.Object,
            mockFactory.Object,
            _mockSasService.Object,
            _mockCloudflareService.Object);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
        _connection.Dispose();
    }

    private static EventGridEvent CreateBlobCreatedEvent(
        string blobUrl,
        string contentType,
        long contentLength,
        string eTag = "\"abc123\"")
    {
        var json = $$"""
            {
                "url": "{{blobUrl}}",
                "contentType": "{{contentType}}",
                "contentLength": {{contentLength}},
                "eTag": {{eTag}},
                "api": "PutBlob",
                "blobType": "BlockBlob"
            }
            """;
        return new EventGridEvent(
            "/blobServices/default/containers/status-videos/blobs/uploads/test.mp4",
            "Microsoft.Storage.BlobCreated",
            "0.0",
            BinaryData.FromString(json));
    }

    private static CloudflareStreamResponse CreateSuccessResponse(string uid = "test-uid-123") =>
        new CloudflareStreamResponse(
            Success: true,
            Result: new CloudflareStreamResult(
                Uid: uid,
                ReadyToStream: false,
                Status: new CloudflareStreamStatus(State: "queued", null, null, null),
                Playback: null),
            Errors: [],
            Messages: []);

    [Fact]
    public async Task RunAsync_ValidMp4Blob_GeneratesReadSasUrlAndSubmitsToCloudflare()
    {
        var blobPath = "uploads/test.mp4";
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = blobPath,
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await _function.RunAsync(evt);

        _mockSasService.Verify(
            s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RunAsync_ValidQuicktimeBlob_ProcessesNormally()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mov",
            ContentType = "video/quicktime",
            FileSizeBytes = 3_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mov",
            "video/quicktime",
            3_000_000);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RunAsync_UnsupportedContentType_DoesNotSubmitToCloudflare()
    {
        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.txt",
            "text/plain",
            1_000);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task RunAsync_ZeroSizeBlob_DoesNotSubmitToCloudflare()
    {
        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            0);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task RunAsync_OversizedBlob_DoesNotSubmitToCloudflare()
    {
        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            52_428_801);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task RunAsync_BlobNotInUploadsPath_DoesNotSubmitToCloudflare()
    {
        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/other/test.mp4",
            "video/mp4",
            5_000_000);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task RunAsync_DuplicateETag_DoesNotSubmitToCloudflareSecondTime()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse());

        var evt1 = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000,
            "\"duplicate-etag\"");
        var evt2 = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000,
            "\"duplicate-etag\"");

        await _function.RunAsync(evt1);
        await _function.RunAsync(evt2);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RunAsync_ValidBlob_CallsGenerateReadSasUrlWithCorrectBlobPath()
    {
        var blobPath = "uploads/test-video.mp4";
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = blobPath,
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            $"https://mystorageaccount.blob.core.windows.net/status-videos/{blobPath}",
            "video/mp4",
            5_000_000);

        await _function.RunAsync(evt);

        _mockSasService.Verify(
            s => s.GenerateReadSasUrlAsync(blobPath, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RunAsync_ValidBlob_CallsSubmitForTranscodingWithSasUrl()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(FakeReadSasUri, It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RunAsync_CloudflareServiceThrows_ExceptionPropagates()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Service unavailable", null, System.Net.HttpStatusCode.ServiceUnavailable));

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await Assert.ThrowsAsync<HttpRequestException>(() => _function.RunAsync(evt));
    }

    [Fact]
    public async Task RunAsync_PermanentCloudflareFailure_DoesNotThrow()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new CloudflareStreamPermanentException("Bad request from Cloudflare"));

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        // Should not throw — permanent failures are acknowledged (no retry)
        await _function.RunAsync(evt);
    }

    // --- T017: Failure and retry behavior tests ---

    [Fact]
    public async Task RunAsync_Cloudflare503_ExceptionPropagates()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Service unavailable", null, System.Net.HttpStatusCode.ServiceUnavailable));

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await Assert.ThrowsAsync<HttpRequestException>(() => _function.RunAsync(evt));
    }

    [Fact]
    public async Task RunAsync_Cloudflare429_ExceptionPropagates()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Too many requests", null, System.Net.HttpStatusCode.TooManyRequests));

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await Assert.ThrowsAsync<HttpRequestException>(() => _function.RunAsync(evt));
    }

    [Fact]
    public async Task RunAsync_CloudflareTimeout_TaskCanceledExceptionPropagates()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new TaskCanceledException("Request timed out"));

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await Assert.ThrowsAsync<TaskCanceledException>(() => _function.RunAsync(evt));
    }

    [Fact]
    public async Task RunAsync_SasUrlGenerationFails_ExceptionPropagates()
    {
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Storage service unavailable"));

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000);

        await Assert.ThrowsAsync<InvalidOperationException>(() => _function.RunAsync(evt));
    }

    [Fact]
    public async Task RunAsync_PermanentCloudflareFailure_AllowsRetryOfSameETag()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);

        _mockCloudflareService
            .SetupSequence(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new CloudflareStreamPermanentException("Bad request"))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000,
            "\"retry-permanent-etag\"");

        // First call — permanent failure acknowledged, eTag removed from cache
        await _function.RunAsync(evt);

        // Second call with same eTag — should re-process since eTag was cleared
        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Exactly(2));
    }

    [Fact]
    public async Task RunAsync_TransientFailure_AllowsRetryOfSameETag()
    {
        _dbContext.Videos.Add(new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);

        _mockCloudflareService
            .SetupSequence(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Service unavailable", null, System.Net.HttpStatusCode.ServiceUnavailable))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/test.mp4",
            "video/mp4",
            5_000_000,
            "\"retry-transient-etag\"");

        // First call — transient failure throws, eTag removed from cache
        await Assert.ThrowsAsync<HttpRequestException>(() => _function.RunAsync(evt));

        // Second call with same eTag — should re-process since eTag was cleared after exception
        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Exactly(2));
    }

    [Fact]
    public async Task RunAsync_ValidBlob_UpdatesVideoStatusToProcessing()
    {
        var videoId = Guid.NewGuid();
        const string blobPath = "uploads/status-video.mp4";
        _dbContext.Videos.Add(new Video
        {
            Id = videoId,
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = blobPath,
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Created,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        var cloudflareUid = "cloudflare-uid-abc123";
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse(cloudflareUid));

        var evt = CreateBlobCreatedEvent(
            $"https://mystorageaccount.blob.core.windows.net/status-videos/{blobPath}",
            "video/mp4",
            5_000_000);

        await _function.RunAsync(evt);

        var videoForReload = await _dbContext.Videos.FindAsync(videoId);
        await _dbContext.Entry(videoForReload!).ReloadAsync();
        var video = await _dbContext.Videos.FindAsync(videoId);
        Assert.NotNull(video);
        Assert.Equal(VideoStatus.Processing, video.Status);
        Assert.Equal(cloudflareUid, video.CloudflareVideoUid);
    }

    [Fact]
    public async Task RunAsync_NoMatchingVideoRecord_LogsWarningAndPassesNullVideoId()
    {
        // No Video seeded — blob has no matching DB record
        var sasResult = new SasUrlResult(FakeReadSasUri, DateTimeOffset.UtcNow.AddMinutes(60));
        _mockSasService
            .Setup(s => s.GenerateReadSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(sasResult);
        _mockCloudflareService
            .Setup(s => s.SubmitForTranscodingAsync(It.IsAny<Uri>(), It.IsAny<Guid?>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateSuccessResponse());

        var evt = CreateBlobCreatedEvent(
            "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/orphan.mp4",
            "video/mp4",
            5_000_000);

        await _function.RunAsync(evt);

        _mockCloudflareService.Verify(
            s => s.SubmitForTranscodingAsync(
                It.IsAny<Uri>(),
                null,
                It.IsAny<string>(),
                It.IsAny<CancellationToken>()),
            Times.Once);

        _mockLogger.Verify(
            l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, _) => v.ToString()!.Contains("No Video record found for blob path")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }
}

