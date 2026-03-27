// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Data;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.EntityFrameworkCore;

namespace Api.Functions;

public sealed class GetSignedStreamUrl(
    IDbContextFactory<StandupDbContext> dbContextFactory,
    ISignedUrlTokenService signedUrlTokenService)
{
    [Function("GetSignedStreamUrl")]
    public async Task<IActionResult> RunAsync(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "video/{videoId}/stream")]
        HttpRequest req,
        string videoId,
        CancellationToken cancellationToken)
    {
        // Parse and validate the streamType query parameter
        var streamTypeValue = req.Query["streamType"].ToString();
        if (!TryParseStreamType(streamTypeValue, out var streamType))
        {
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "invalid_stream_type",
                    "The streamType query parameter must be 'hls' or 'dash'.")));
        }

        // Look up the video by ID
        if (!Guid.TryParse(videoId, out var videoGuid))
        {
            return new NotFoundObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "video_not_found",
                    "No video was found with the specified ID.")));
        }

        await using var dbContext = await dbContextFactory.CreateDbContextAsync(cancellationToken);
        var video = await dbContext.Videos
            .FirstOrDefaultAsync(v => v.Id == videoGuid, cancellationToken);

        if (video is null)
        {
            return new NotFoundObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "video_not_found",
                    "No video was found with the specified ID.")));
        }

        if (video.Status != VideoStatus.Ready || video.CloudflareVideoUid is null)
        {
            return new ObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "video_not_ready",
                    $"The video is not yet ready for streaming. Current status: {video.Status.ToString().ToLowerInvariant()}.")))
            { StatusCode = StatusCodes.Status409Conflict };
        }

        var result = await signedUrlTokenService.GenerateSignedUrlAsync(
            video.CloudflareVideoUid,
            streamType,
            cancellationToken);

        return new OkObjectResult(
            new GetSignedStreamUrlResponse(
                result.SignedUrl,
                result.ExpiresAt.ToString("O")));
    }

    private static bool TryParseStreamType(string? value, out StreamType streamType)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            streamType = default;
            return false;
        }

        if (value.Equals("hls", StringComparison.OrdinalIgnoreCase))
        {
            streamType = StreamType.Hls;
            return true;
        }

        if (value.Equals("dash", StringComparison.OrdinalIgnoreCase))
        {
            streamType = StreamType.Dash;
            return true;
        }

        streamType = default;
        return false;
    }
}
