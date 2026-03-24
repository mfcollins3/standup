// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Api.Models;

public record CloudflareStreamResponse(
    [property: JsonPropertyName("success")] bool Success,
    [property: JsonPropertyName("result")] CloudflareStreamResult? Result,
    [property: JsonPropertyName("errors")] List<CloudflareApiError> Errors,
    [property: JsonPropertyName("messages")] List<CloudflareApiMessage> Messages
);

public record CloudflareStreamResult(
    [property: JsonPropertyName("uid")] string Uid,
    [property: JsonPropertyName("readyToStream")] bool ReadyToStream,
    [property: JsonPropertyName("status")] CloudflareStreamStatus? Status,
    [property: JsonPropertyName("playback")] CloudflarePlayback? Playback
);

public record CloudflareStreamStatus(
    [property: JsonPropertyName("state")] string State,
    [property: JsonPropertyName("pctComplete")] string? PctComplete,
    [property: JsonPropertyName("errorReasonCode")] string? ErrorReasonCode,
    [property: JsonPropertyName("errorReasonText")] string? ErrorReasonText
);

public record CloudflarePlayback(
    [property: JsonPropertyName("hls")] string? Hls,
    [property: JsonPropertyName("dash")] string? Dash
);

public record CloudflareApiError(
    [property: JsonPropertyName("code")] int Code,
    [property: JsonPropertyName("message")] string Message
);

public record CloudflareApiMessage(
    [property: JsonPropertyName("code")] int Code,
    [property: JsonPropertyName("message")] string Message
);
