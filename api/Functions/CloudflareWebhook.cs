// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json;
using Api.Data;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Functions;

public sealed class CloudflareWebhook(
    ILogger<CloudflareWebhook> logger,
    IDbContextFactory<StandupDbContext> dbContextFactory,
    IWebhookSignatureService signatureService)
{
    private static readonly JsonSerializerOptions DeserializeOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    [Function(nameof(CloudflareWebhook))]
    public async Task<IActionResult> RunAsync(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post",
            Route = "webhooks/cloudflare/stream")]
        HttpRequest request,
        CancellationToken cancellationToken)
    {
        var body = await new StreamReader(request.Body).ReadToEndAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(body))
        {
            logger.LogWarning("Webhook request rejected: empty request body.");
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "bad_request",
                    "Request body is required.")));
        }

        var signatureHeader = request.Headers["Webhook-Signature"].ToString();
        if (!signatureService.VerifySignature(signatureHeader, body))
        {
            logger.LogWarning(
                "Webhook request rejected: signature verification failed. "
                + "SignaturePresent={SignaturePresent}",
                !string.IsNullOrEmpty(signatureHeader));
            return new UnauthorizedObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "unauthorized",
                    "Request signature is missing or invalid.")));
        }

        CloudflareWebhookPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<CloudflareWebhookPayload>(
                body,
                DeserializeOptions);
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "Webhook request rejected: invalid JSON payload.");
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "bad_request",
                    "Invalid JSON payload.")));
        }

        if (payload is null)
        {
            logger.LogWarning("Webhook request rejected: JSON payload deserialized to null.");
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "bad_request",
                    "Invalid JSON payload.")));
        }

        var hasMetaVideoId = payload.Meta is not null
            && payload.Meta.ContainsKey("videoId");

        if (payload.ReadyToStream)
        {
            logger.LogInformation(
                "Video {VideoUid} is ready to stream. "
                + "Duration={Duration}s, Size={Size}",
                payload.Uid,
                payload.Duration,
                payload.Size);

            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
            var video = await FindVideoAsync(dbContext, payload, cancellationToken);

            if (video is not null)
            {
                video.HlsUrl = payload.Playback?.Hls;
                video.DashUrl = payload.Playback?.Dash;
                video.ThumbnailUrl = payload.Thumbnail;
                video.Duration = payload.Duration;
                video.InputWidth = payload.Input?.Width;
                video.InputHeight = payload.Input?.Height;
                video.Status = VideoStatus.Ready;
                video.UpdatedAt = DateTimeOffset.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            else
            {
                logger.LogWarning(
                    "No matching video found for ready-to-stream webhook. "
                    + "Uid={VideoUid}, HasMetaVideoId={HasMetaVideoId}",
                    payload.Uid,
                    hasMetaVideoId);
            }
        }
        else if (payload.Status?.State == "error")
        {
            logger.LogWarning(
                "Video {VideoUid} processing failed. "
                + "ErrorCode={ErrorCode}, ErrorText={ErrorText}",
                payload.Uid,
                payload.Status.ErrorReasonCode,
                payload.Status.ErrorReasonText);

            await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
            var video = await FindVideoAsync(dbContext, payload, cancellationToken);

            if (video is not null)
            {
                video.ErrorReasonCode = payload.Status.ErrorReasonCode;
                video.ErrorReasonText = payload.Status.ErrorReasonText;
                video.Status = VideoStatus.Failed;
                video.UpdatedAt = DateTimeOffset.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            else
            {
                logger.LogWarning(
                    "No matching video found for error webhook. "
                    + "Uid={VideoUid}, HasMetaVideoId={HasMetaVideoId}",
                    payload.Uid,
                    hasMetaVideoId);
            }
        }

        return new OkResult();
    }

    private static async Task<Video?> FindVideoAsync(
        StandupDbContext dbContext,
        CloudflareWebhookPayload payload,
        CancellationToken cancellationToken)
    {
        if (payload.Meta is not null &&
            payload.Meta.TryGetValue("videoId", out var videoIdObj) &&
            Guid.TryParse(videoIdObj?.ToString(), out var videoId))
        {
            var video = await dbContext.Videos.FindAsync([videoId], cancellationToken);
            if (video is not null)
            {
                return video;
            }
        }

        if (payload.Uid is not null)
        {
            return await dbContext.Videos
                .FirstOrDefaultAsync(v => v.CloudflareVideoUid == payload.Uid, cancellationToken);
        }

        return null;
    }
}
