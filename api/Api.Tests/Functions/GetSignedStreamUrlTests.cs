// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Data;
using Api.Functions;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Moq;
using Xunit;

namespace Api.Tests.Functions;

public sealed class GetSignedStreamUrlTests : IDisposable
{
    private const string FakeSignedUrl =
        "https://customer-abc12345.cloudflarestream.com/eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ2aWQxMjMifQ.sig/manifest/video.m3u8";

    private readonly Mock<ISignedUrlTokenService> _mockTokenService;
    private readonly SqliteConnection _connection;
    private readonly StandupDbContext _dbContext;
    private readonly GetSignedStreamUrl _function;

    public GetSignedStreamUrlTests()
    {
        _mockTokenService = new Mock<ISignedUrlTokenService>();

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

        _function = new GetSignedStreamUrl(mockFactory.Object, _mockTokenService.Object);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
        _connection.Dispose();
    }

    private HttpRequest BuildRequest(string? streamType = "hls")
    {
        var context = new DefaultHttpContext();
        if (streamType is not null)
        {
            context.Request.QueryString = new QueryString($"?streamType={streamType}");
        }
        return context.Request;
    }

    private async Task<Guid> SeedReadyVideoAsync(string? cloudflareVideoUid = "vid123uid")
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Ready,
            CloudflareVideoUid = cloudflareVideoUid,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };
        _dbContext.Videos.Add(video);
        await _dbContext.SaveChangesAsync();
        return video.Id;
    }

    [Fact]
    public async Task RunAsync_ValidVideoAndHlsStreamType_Returns200WithSignedUrl()
    {
        var videoId = await SeedReadyVideoAsync();
        var expiresAt = DateTimeOffset.UtcNow.AddHours(1);
        _mockTokenService
            .Setup(s => s.GenerateSignedUrlAsync(
                It.IsAny<string>(), StreamType.Hls, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SignedStreamUrlResult(FakeSignedUrl, expiresAt));

        var req = BuildRequest("hls");
        var result = await _function.RunAsync(req, videoId.ToString(), CancellationToken.None);

        var ok = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<GetSignedStreamUrlResponse>(ok.Value);
        Assert.Equal(FakeSignedUrl, response.SignedUrl);
        Assert.NotEmpty(response.ExpiresAt);
    }

    [Fact]
    public async Task RunAsync_ValidVideoAndDashStreamType_Returns200WithSignedUrl()
    {
        var videoId = await SeedReadyVideoAsync();
        var expiresAt = DateTimeOffset.UtcNow.AddHours(1);
        _mockTokenService
            .Setup(s => s.GenerateSignedUrlAsync(
                It.IsAny<string>(), StreamType.Dash, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SignedStreamUrlResult(FakeSignedUrl.Replace("m3u8", "mpd"), expiresAt));

        var req = BuildRequest("dash");
        var result = await _function.RunAsync(req, videoId.ToString(), CancellationToken.None);

        var ok = Assert.IsType<OkObjectResult>(result);
        Assert.IsType<GetSignedStreamUrlResponse>(ok.Value);
    }

    [Fact]
    public async Task RunAsync_StreamTypeCaseInsensitive_Returns200()
    {
        var videoId = await SeedReadyVideoAsync();
        var expiresAt = DateTimeOffset.UtcNow.AddHours(1);
        _mockTokenService
            .Setup(s => s.GenerateSignedUrlAsync(
                It.IsAny<string>(), StreamType.Hls, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SignedStreamUrlResult(FakeSignedUrl, expiresAt));

        var req = BuildRequest("HLS");
        var result = await _function.RunAsync(req, videoId.ToString(), CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_VideoNotFound_Returns404()
    {
        var nonexistentId = Guid.NewGuid().ToString();
        var req = BuildRequest("hls");

        var result = await _function.RunAsync(req, nonexistentId, CancellationToken.None);

        var notFound = Assert.IsType<NotFoundObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(notFound.Value);
        Assert.Equal("video_not_found", error.Error.Code);
    }

    [Fact]
    public async Task RunAsync_VideoNotReady_Returns409()
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/processing.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Processing,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };
        _dbContext.Videos.Add(video);
        await _dbContext.SaveChangesAsync();

        var req = BuildRequest("hls");
        var result = await _function.RunAsync(req, video.Id.ToString(), CancellationToken.None);

        var conflict = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status409Conflict, conflict.StatusCode);
        var error = Assert.IsType<ErrorResponse>(conflict.Value);
        Assert.Equal("video_not_ready", error.Error.Code);
    }

    [Fact]
    public async Task RunAsync_InvalidStreamType_Returns400()
    {
        var videoId = await SeedReadyVideoAsync();
        var req = BuildRequest("invalid_format");

        var result = await _function.RunAsync(req, videoId.ToString(), CancellationToken.None);

        var bad = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(bad.Value);
        Assert.Equal("invalid_stream_type", error.Error.Code);
    }

    [Fact]
    public async Task RunAsync_MissingStreamType_Returns400()
    {
        var videoId = await SeedReadyVideoAsync();
        var req = BuildRequest(null);

        var result = await _function.RunAsync(req, videoId.ToString(), CancellationToken.None);

        var bad = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(bad.Value);
        Assert.Equal("invalid_stream_type", error.Error.Code);
    }

    [Fact]
    public async Task RunAsync_VideoReadyButCloudflareVideoUidIsNull_Returns409()
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/nouid.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 5_000_000,
            Status = VideoStatus.Ready,
            CloudflareVideoUid = null,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };
        _dbContext.Videos.Add(video);
        await _dbContext.SaveChangesAsync();

        var req = BuildRequest("hls");
        var result = await _function.RunAsync(req, video.Id.ToString(), CancellationToken.None);

        var conflict = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status409Conflict, conflict.StatusCode);
        var error = Assert.IsType<ErrorResponse>(conflict.Value);
        Assert.Equal("video_not_ready", error.Error.Code);
    }

    [Fact]
    public async Task RunAsync_InvalidVideoIdFormat_Returns404()
    {
        var req = BuildRequest("hls");
        var result = await _function.RunAsync(req, "not-a-guid", CancellationToken.None);

        var notFound = Assert.IsType<NotFoundObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(notFound.Value);
        Assert.Equal("video_not_found", error.Error.Code);
    }
}
