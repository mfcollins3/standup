// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Models;

namespace Api.Services;

public interface ICloudflareStreamService
{
    Task<CloudflareStreamResponse> SubmitForTranscodingAsync(
        Uri videoReadUrl,
        string blobPath,
        CancellationToken cancellationToken = default);
}
