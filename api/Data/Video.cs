// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

namespace Api.Data;

public class Video
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string BlobPath { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public VideoStatus Status { get; set; }
    public string? CloudflareVideoUid { get; set; }
    public string? HlsUrl { get; set; }
    public string? DashUrl { get; set; }
    public string? ThumbnailUrl { get; set; }
    public double? Duration { get; set; }
    public int? InputWidth { get; set; }
    public int? InputHeight { get; set; }
    public string? ErrorReasonCode { get; set; }
    public string? ErrorReasonText { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
