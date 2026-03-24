// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

namespace Api.Services;

public interface IWebhookSignatureService
{
    bool VerifySignature(string? signatureHeader, string requestBody);
}
