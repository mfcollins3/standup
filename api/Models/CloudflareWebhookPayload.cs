// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json.Serialization;

namespace Api.Models;

public record CloudflareWebhookPayload(
    [property: JsonPropertyName("uid")] string? Uid,
    [property: JsonPropertyName("readyToStream")] bool ReadyToStream,
    [property: JsonPropertyName("status")] CloudflareStreamStatus? Status,
    [property: JsonPropertyName("meta")] Dictionary<string, object>? Meta,
    [property: JsonPropertyName("duration")] double? Duration,
    [property: JsonPropertyName("input")] CloudflareVideoInput? Input,
    [property: JsonPropertyName("playback")] CloudflarePlayback? Playback,
    [property: JsonPropertyName("thumbnail")] string? Thumbnail,
    [property: JsonPropertyName("created")] string? Created,
    [property: JsonPropertyName("modified")] string? Modified,
    [property: JsonPropertyName("size")] long? Size,
    [property: JsonPropertyName("preview")] string? Preview);

public record CloudflareVideoInput(
    [property: JsonPropertyName("width")] int? Width,
    [property: JsonPropertyName("height")] int? Height);
