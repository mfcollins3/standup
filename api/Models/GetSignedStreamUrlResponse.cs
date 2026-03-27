// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json.Serialization;

namespace Api.Models;

public record GetSignedStreamUrlResponse(
    [property: JsonPropertyName("signedUrl")] string SignedUrl,
    [property: JsonPropertyName("expiresAt")] string ExpiresAt);
