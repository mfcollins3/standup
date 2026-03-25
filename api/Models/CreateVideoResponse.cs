// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json.Serialization;

namespace Api.Models;

public record CreateVideoResponse(
    [property: JsonPropertyName("videoId")] Guid VideoId,
    [property: JsonPropertyName("uploadUrl")] string UploadUrl,
    [property: JsonPropertyName("expiresAt")] string ExpiresAt);
