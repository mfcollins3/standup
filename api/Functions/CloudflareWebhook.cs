// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json;
using Api.Models;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Api.Functions;

public sealed class CloudflareWebhook(
    ILogger<CloudflareWebhook> logger,
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

        if (payload.ReadyToStream)
        {
            logger.LogInformation(
                "Video {VideoUid} is ready to stream. "
                + "Duration={Duration}s, Size={Size}",
                payload.Uid,
                payload.Duration,
                payload.Size);
        }
        else if (payload.Status?.State == "error")
        {
            logger.LogWarning(
                "Video {VideoUid} processing failed. "
                + "ErrorCode={ErrorCode}, ErrorText={ErrorText}",
                payload.Uid,
                payload.Status.ErrorReasonCode,
                payload.Status.ErrorReasonText);
        }

        if (payload.Meta is not null)
        {
            payload.Meta.TryGetValue("blobpath", out var blobPath);
            payload.Meta.TryGetValue("filename", out var fileName);
            if (blobPath is not null || fileName is not null)
            {
                logger.LogInformation(
                    "Webhook metadata for video {VideoUid}: "
                    + "BlobPath={BlobPath}, FileName={FileName}",
                    payload.Uid,
                    blobPath,
                    fileName);
            }
        }

        return new OkResult();
    }
}
