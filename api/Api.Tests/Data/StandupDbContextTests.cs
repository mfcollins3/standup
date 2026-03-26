// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Data;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests.Data;

public class StandupDbContextTests : IDisposable
{
    private readonly StandupDbContext _context;

    public StandupDbContextTests()
    {
        var options = new DbContextOptionsBuilder<StandupDbContext>()
            .UseSqlite("DataSource=:memory:")
            .Options;

        _context = new StandupDbContext(options);
        _context.Database.OpenConnection();
        _context.Database.EnsureCreated();
    }

    public void Dispose()
    {
        _context.Dispose();
    }

    [Fact]
    public async Task Videos_CanInsertAndRetrieveEntity()
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/test-video.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 1024,
            Status = VideoStatus.Created,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        _context.Videos.Add(video);
        await _context.SaveChangesAsync();

        var retrieved = await _context.Videos.FindAsync(video.Id);

        Assert.NotNull(retrieved);
        Assert.Equal(video.Id, retrieved.Id);
        Assert.Equal(VideoConstants.PlaceholderUserId, retrieved.UserId);
        Assert.Equal("uploads/test-video.mp4", retrieved.BlobPath);
        Assert.Equal("video/mp4", retrieved.ContentType);
        Assert.Equal(1024L, retrieved.FileSizeBytes);
        Assert.Equal(VideoStatus.Created, retrieved.Status);
    }

    [Fact]
    public async Task Videos_StatusStoredAsString()
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/status-as-string.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 512,
            Status = VideoStatus.Ready,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        _context.Videos.Add(video);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        // Query the raw stored value directly via ADO.NET to confirm string storage.
        var connection = _context.Database.GetDbConnection();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT status FROM \"Videos\" LIMIT 1";
        var rawStatus = (string?)await command.ExecuteScalarAsync();

        Assert.Equal("Ready", rawStatus);
    }

    [Fact]
    public async Task Videos_BlobPathIsUnique()
    {
        var blobPath = "uploads/unique-video.mp4";
        var now = DateTimeOffset.UtcNow;

        _context.Videos.AddRange(
            new Video
            {
                Id = Guid.NewGuid(),
                UserId = VideoConstants.PlaceholderUserId,
                BlobPath = blobPath,
                ContentType = "video/mp4",
                FileSizeBytes = 1024,
                Status = VideoStatus.Created,
                CreatedAt = now,
                UpdatedAt = now,
            },
            new Video
            {
                Id = Guid.NewGuid(),
                UserId = VideoConstants.PlaceholderUserId,
                BlobPath = blobPath,
                ContentType = "video/mp4",
                FileSizeBytes = 1024,
                Status = VideoStatus.Created,
                CreatedAt = now,
                UpdatedAt = now,
            });

        await Assert.ThrowsAsync<DbUpdateException>(() => _context.SaveChangesAsync());
    }

    [Fact]
    public async Task Videos_NullableFieldsAllowNull()
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/nullable-fields.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 256,
            Status = VideoStatus.Created,
            CloudflareVideoUid = null,
            HlsUrl = null,
            DashUrl = null,
            ThumbnailUrl = null,
            Duration = null,
            InputWidth = null,
            InputHeight = null,
            ErrorReasonCode = null,
            ErrorReasonText = null,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        _context.Videos.Add(video);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        var retrieved = await _context.Videos.FindAsync(video.Id);

        Assert.NotNull(retrieved);
        Assert.Null(retrieved.CloudflareVideoUid);
        Assert.Null(retrieved.HlsUrl);
        Assert.Null(retrieved.DashUrl);
        Assert.Null(retrieved.ThumbnailUrl);
        Assert.Null(retrieved.Duration);
        Assert.Null(retrieved.InputWidth);
        Assert.Null(retrieved.InputHeight);
        Assert.Null(retrieved.ErrorReasonCode);
        Assert.Null(retrieved.ErrorReasonText);
    }

    [Fact]
    public async Task Videos_CanQueryByBlobPath()
    {
        var blobPath = "uploads/query-by-blob.mp4";
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = blobPath,
            ContentType = "video/mp4",
            FileSizeBytes = 2048,
            Status = VideoStatus.Uploaded,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        _context.Videos.Add(video);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        var retrieved = await _context.Videos
            .SingleOrDefaultAsync(v => v.BlobPath == blobPath);

        Assert.NotNull(retrieved);
        Assert.Equal(video.Id, retrieved.Id);
    }

    [Fact]
    public async Task Videos_CanQueryByCloudflareVideoUid()
    {
        var uid = "abc123";
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/query-by-uid.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 4096,
            Status = VideoStatus.Processing,
            CloudflareVideoUid = uid,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        _context.Videos.Add(video);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        var retrieved = await _context.Videos
            .SingleOrDefaultAsync(v => v.CloudflareVideoUid == uid);

        Assert.NotNull(retrieved);
        Assert.Equal(video.Id, retrieved.Id);
    }

    [Fact]
    public async Task Videos_CanTransitionStatusFromCreatedToUploaded()
    {
        var video = new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = "uploads/status-transition.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 8192,
            Status = VideoStatus.Created,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        _context.Videos.Add(video);
        await _context.SaveChangesAsync();

        video.Status = VideoStatus.Uploaded;
        video.UpdatedAt = DateTimeOffset.UtcNow;
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        var retrieved = await _context.Videos.FindAsync(video.Id);

        Assert.NotNull(retrieved);
        Assert.Equal(VideoStatus.Uploaded, retrieved.Status);
    }

    [Fact]
    public async Task Videos_AllVideoStatusValuesRoundTrip()
    {
        var statuses = Enum.GetValues<VideoStatus>();
        var now = DateTimeOffset.UtcNow;
        var videos = statuses.Select((status, i) => new Video
        {
            Id = Guid.NewGuid(),
            UserId = VideoConstants.PlaceholderUserId,
            BlobPath = $"uploads/status-roundtrip-{i}.mp4",
            ContentType = "video/mp4",
            FileSizeBytes = 1024,
            Status = status,
            CreatedAt = now,
            UpdatedAt = now,
        }).ToList();

        _context.Videos.AddRange(videos);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        foreach (var video in videos)
        {
            var retrieved = await _context.Videos.FindAsync(video.Id);
            Assert.NotNull(retrieved);
            Assert.Equal(video.Status, retrieved.Status);
        }
    }
}
