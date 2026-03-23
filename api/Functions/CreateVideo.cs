// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;

namespace Api.Functions;

public sealed class CreateVideo(ISasUrlService sasUrlService)
{
    private static readonly HashSet<string> AllowedContentTypes =
        ["video/mp4", "video/quicktime"];

    private const long MaxFileSizeBytes = 52_428_800L;

    private static readonly JsonSerializerOptions DeserializeOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    [Function("CreateVideo")]
    public async Task<IActionResult> RunAsync(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "video")]
        HttpRequest req,
        CancellationToken cancellationToken)
    {
        CreateVideoRequest? request;
        try
        {
            request = await JsonSerializer.DeserializeAsync<CreateVideoRequest>(
                req.Body,
                DeserializeOptions,
                cancellationToken);
        }
        catch (JsonException)
        {
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail("bad_request", "Invalid request body.")));
        }

        if (request is null)
        {
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail("bad_request", "Request body is required.")));
        }

        if (!AllowedContentTypes.Contains(request.ContentType))
        {
            return new ObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "unsupported_media_type",
                    $"Content type '{request.ContentType}' is not supported.")))
            { StatusCode = StatusCodes.Status415UnsupportedMediaType };
        }

        if (request.FileSizeBytes <= 0 || request.FileSizeBytes > MaxFileSizeBytes)
        {
            return new BadRequestObjectResult(
                new ErrorResponse(new ErrorDetail(
                    "bad_request",
                    $"File size must be between 1 and {MaxFileSizeBytes} bytes.")));
        }

        var blobPath = $"uploads/anonymous/{Guid.NewGuid()}.mp4";
        var result = await sasUrlService.GenerateSasUrlAsync(blobPath, cancellationToken);

        return new OkObjectResult(
            new CreateVideoResponse(result.SasUri.ToString(), result.ExpiresAt.ToString("O")));
    }
}
