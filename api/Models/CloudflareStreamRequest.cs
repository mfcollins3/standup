// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Api.Models;

public record CloudflareStreamRequest(
    [property: JsonPropertyName("url")] string Url,
    [property: JsonPropertyName("meta")] Dictionary<string, string>? Meta = null,
    [property: JsonPropertyName("requireSignedURLs")] bool? RequireSignedURLs = null
);
