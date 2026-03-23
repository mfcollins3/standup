// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

namespace Api.Services;

public record SasUrlResult(Uri SasUri, DateTimeOffset ExpiresAt);

public interface ISasUrlService
{
    Task<SasUrlResult> GenerateSasUrlAsync(
        string blobPath,
        CancellationToken cancellationToken = default);
}
