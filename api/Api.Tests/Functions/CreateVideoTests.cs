// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
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

public sealed class CreateVideoTests : IDisposable
{
    private static readonly Uri FakeSasUri = new(
        "https://mystorageaccount.blob.core.windows.net/status-videos/uploads/anonymous/00000000-0000-0000-0000-000000000000.mp4?sv=2025-01-05&se=...&sp=cw&spr=https&sig=...");

    private readonly Mock<ISasUrlService> _mockSasService;
    private readonly SqliteConnection _connection;
    private readonly StandupDbContext _dbContext;
    private readonly IDbContextFactory<StandupDbContext> _dbContextFactory;
    private readonly CreateVideo _function;

    public CreateVideoTests()
    {
        _mockSasService = new Mock<ISasUrlService>();

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
        _dbContextFactory = mockFactory.Object;

        _function = new CreateVideo(_dbContextFactory, _mockSasService.Object);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task RunAsync_ValidMp4Request_Returns200WithUploadUrlAndExpiresAt()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 12_345_678 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        var ok = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<CreateVideoResponse>(ok.Value);
        Assert.NotEqual(Guid.Empty, response.VideoId);
        Assert.NotEmpty(response.UploadUrl);
        Assert.NotEmpty(response.ExpiresAt);
    }

    [Fact]
    public async Task RunAsync_ValidQuicktimeRequest_Returns200()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/quicktime", fileSizeBytes = 1_000_000 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_UnsupportedContentType_Returns415()
    {
        var req = BuildRequest(new { contentType = "video/avi", fileSizeBytes = 12_345_678 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status415UnsupportedMediaType, objectResult.StatusCode);
    }

    [Fact]
    public async Task RunAsync_FileSizeTooLarge_Returns400()
    {
        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 52_428_801 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_FileSizeZero_Returns400()
    {
        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 0 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_FileSizeAtMaximum_Returns200()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 52_428_800 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_ValidRequest_BlobPathMatchesExpectedPattern()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        string? capturedBlobPath = null;
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Callback<string, CancellationToken>((path, _) => capturedBlobPath = path)
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 12_345_678 });
        await _function.RunAsync(req, CancellationToken.None);

        Assert.NotNull(capturedBlobPath);
        Assert.Matches(
            new Regex(@"^uploads/[^/]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.mp4$"),
            capturedBlobPath);
    }

    [Fact]
    public async Task RunAsync_QuicktimeRequest_BlobPathUsesMovExtension()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        string? capturedBlobPath = null;
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Callback<string, CancellationToken>((path, _) => capturedBlobPath = path)
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/quicktime", fileSizeBytes = 1_000_000 });
        await _function.RunAsync(req, CancellationToken.None);

        Assert.NotNull(capturedBlobPath);
        Assert.Matches(
            new Regex(@"^uploads/[^/]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.mov$"),
            capturedBlobPath);
    }

    [Fact]
    public async Task RunAsync_ValidRequest_ExpiresAtIsApproximately15MinutesFromNow()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 12_345_678 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        var ok = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<CreateVideoResponse>(ok.Value);
        Assert.NotEqual(Guid.Empty, response.VideoId);
        var expiresAt = DateTimeOffset.Parse(response.ExpiresAt);
        var delta = expiresAt - DateTimeOffset.UtcNow;
        Assert.InRange(delta.TotalMinutes, 14.0, 16.0);
    }

    [Fact]
    public async Task RunAsync_InvalidJson_Returns400()
    {
        var req = BuildRawRequest("not valid json");
        var result = await _function.RunAsync(req, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_EmptyBody_Returns400()
    {
        var req = BuildRawRequest("");
        var result = await _function.RunAsync(req, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task RunAsync_ValidRequest_InsertsVideoRecordWithCreatedStatus()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 12_345_678 });
        await _function.RunAsync(req, CancellationToken.None);

        var video = await _dbContext.Videos.SingleAsync();
        Assert.Equal(VideoStatus.Created, video.Status);
    }

    [Fact]
    public async Task RunAsync_ValidRequest_InsertsVideoRecordWithPlaceholderUserId()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 12_345_678 });
        await _function.RunAsync(req, CancellationToken.None);

        var video = await _dbContext.Videos.SingleAsync();
        Assert.Equal(VideoConstants.PlaceholderUserId, video.UserId);
    }

    [Fact]
    public async Task RunAsync_ValidRequest_VideoIdInResponseMatchesInsertedRecord()
    {
        var expectedExpiry = DateTimeOffset.UtcNow.AddMinutes(15);
        _mockSasService
            .Setup(s => s.GenerateSasUrlAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SasUrlResult(FakeSasUri, expectedExpiry));

        var req = BuildRequest(new { contentType = "video/mp4", fileSizeBytes = 12_345_678 });
        var result = await _function.RunAsync(req, CancellationToken.None);

        var ok = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<CreateVideoResponse>(ok.Value);
        var video = await _dbContext.Videos.SingleAsync();
        Assert.Equal(video.Id, response.VideoId);
    }

    private static HttpRequest BuildRequest(object body)
    {
        var json = JsonSerializer.Serialize(body);
        return BuildRawRequest(json);
    }

    private static HttpRequest BuildRawRequest(string body)
    {
        var context = new DefaultHttpContext();
        context.Request.Method = "POST";
        context.Request.ContentType = "application/json";
        var bytes = Encoding.UTF8.GetBytes(body);
        context.Request.Body = new MemoryStream(bytes);
        context.Request.ContentLength = bytes.Length;
        return context.Request;
    }
}
