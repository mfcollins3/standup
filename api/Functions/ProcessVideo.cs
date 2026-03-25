// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Collections.Concurrent;
using Azure.Messaging.EventGrid;
using Azure.Messaging.EventGrid.SystemEvents;
using Azure.Storage.Blobs;
using Api.Data;
using Api.Models;
using Api.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Functions;

public sealed class ProcessVideo(
    ILogger<ProcessVideo> logger,
    IDbContextFactory<StandupDbContext> dbContextFactory,
    ISasUrlService sasUrlService,
    ICloudflareStreamService cloudflareStreamService)
{
    private const long MaxBlobSizeBytes = 52_428_800; // 50 MB
    private static readonly string[] SupportedContentTypes = ["video/mp4", "video/quicktime"];

    private readonly ConcurrentDictionary<string, bool> _processedETags = new();

    [Function(nameof(ProcessVideo))]
    public async Task RunAsync(
        [EventGridTrigger] EventGridEvent eventGridEvent,
        CancellationToken cancellationToken = default)
    {
        var blobData = eventGridEvent.Data.ToObjectFromJson<StorageBlobCreatedEventData>();

        var blobUri = new Uri(blobData!.Url);
        var blobUriBuilder = new BlobUriBuilder(blobUri);
        var blobPath = blobUriBuilder.BlobName;
        var contentType = blobData.ContentType;
        var contentLength = blobData.ContentLength;
        var eTag = blobData.ETag;

        logger.LogInformation(
            "Video blob created event received. BlobPath={BlobPath}, "
            + "ContentType={ContentType}, ContentLength={ContentLength}, ETag={ETag}",
            blobPath, contentType, contentLength, eTag);

        if (!blobPath.StartsWith("uploads/", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation(
                "Blob skipped: not in uploads/ path. BlobPath={BlobPath}, Reason={Reason}",
                blobPath, "WrongPathPrefix");
            return;
        }

        if (!SupportedContentTypes.Contains(contentType, StringComparer.OrdinalIgnoreCase))
        {
            logger.LogInformation(
                "Blob skipped: unsupported content type. BlobPath={BlobPath}, "
                + "ContentType={ContentType}, Reason={Reason}",
                blobPath, contentType, "UnsupportedContentType");
            return;
        }

        if (contentLength <= 0 || contentLength > MaxBlobSizeBytes)
        {
            logger.LogInformation(
                "Blob skipped: content length out of range. BlobPath={BlobPath}, "
                + "ContentLength={ContentLength}, Reason={Reason}",
                blobPath, contentLength, "InvalidSize");
            return;
        }

        if (!_processedETags.TryAdd(eTag, true))
        {
            logger.LogInformation(
                "Blob skipped: duplicate event. BlobPath={BlobPath}, "
                + "ETag={ETag}, Reason={Reason}",
                blobPath, eTag, "DuplicateETag");
            return;
        }

        // ETag was added; remove it if processing fails so Event Grid retries can succeed
        try
        {
            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
            var video = await dbContext.Videos
                .FirstOrDefaultAsync(v => v.BlobPath == blobPath, cancellationToken);

            if (video is null)
            {
                logger.LogWarning(
                    "No Video record found for blob path. BlobPath={BlobPath}",
                    blobPath);
            }

            var sasResult = await sasUrlService.GenerateReadSasUrlAsync(blobPath, cancellationToken);

            logger.LogInformation(
                "SAS URL generated for blob. BlobPath={BlobPath}, SasExpiry={SasExpiry}",
                blobPath, sasResult.ExpiresAt);

            CloudflareStreamResponse cfResponse;
            try
            {
                cfResponse = await cloudflareStreamService.SubmitForTranscodingAsync(
                    sasResult.SasUri, video?.Id, blobPath, cancellationToken);
            }
            catch (CloudflareStreamPermanentException ex)
            {
                // Permanent failure — acknowledge event, do not retry
                _processedETags.TryRemove(eTag, out _);
                logger.LogError(
                    ex,
                    "Permanent Cloudflare Stream error. BlobPath={BlobPath}, "
                    + "ContentType={ContentType}, ContentLength={ContentLength}, "
                    + "FailureClassification={FailureClassification}",
                    blobPath, contentType, contentLength, "Permanent");
                return;
            }

            logger.LogInformation(
                "Video submitted for transcoding. BlobPath={BlobPath}, "
                + "VideoUid={VideoUid}, State={State}",
                blobPath, cfResponse.Result?.Uid, cfResponse.Result?.Status?.State);

            if (video is not null)
            {
                video.Status = VideoStatus.Processing;
                video.CloudflareVideoUid = cfResponse.Result?.Uid;
                video.UpdatedAt = DateTimeOffset.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
        }
        catch
        {
            // Transient failure — remove eTag so a retry can re-process this event
            _processedETags.TryRemove(eTag, out _);
            throw;
        }
    }
}
