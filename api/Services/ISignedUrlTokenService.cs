// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Api.Models;

namespace Api.Services;

public interface ISignedUrlTokenService
{
    Task<SignedStreamUrlResult> GenerateSignedUrlAsync(
        string cloudflareVideoUid,
        StreamType streamType,
        CancellationToken cancellationToken = default);
}

public record SignedStreamUrlResult(
    string SignedUrl,
    DateTimeOffset ExpiresAt);
