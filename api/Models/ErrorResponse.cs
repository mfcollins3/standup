// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Text.Json.Serialization;

namespace Api.Models;

public record ErrorDetail(
    [property: JsonPropertyName("code")] string Code,
    [property: JsonPropertyName("message")] string Message);

public record ErrorResponse(
    [property: JsonPropertyName("error")] ErrorDetail Error);
