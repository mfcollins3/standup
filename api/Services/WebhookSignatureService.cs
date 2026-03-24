// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace Api.Services;

public sealed class WebhookSignatureService : IWebhookSignatureService
{
    private readonly string _secret;

    public WebhookSignatureService(IConfiguration configuration)
    {
        _secret = configuration["CLOUDFLARE_WEBHOOK_SIGNING_SECRET"]
            ?? throw new InvalidOperationException(
                "Required configuration setting "
                + "'CLOUDFLARE_WEBHOOK_SIGNING_SECRET' is missing.");
    }

    public bool VerifySignature(string? signatureHeader, string requestBody)
    {
        if (string.IsNullOrEmpty(signatureHeader))
            return false;

        if (string.IsNullOrEmpty(requestBody))
            return false;

        string? time = null;
        string? sig1 = null;

        foreach (var part in signatureHeader.Split(','))
        {
            var trimmed = part.Trim();
            if (trimmed.StartsWith("time=", StringComparison.Ordinal))
                time = trimmed["time=".Length..];
            else if (trimmed.StartsWith("sig1=", StringComparison.Ordinal))
                sig1 = trimmed["sig1=".Length..];
        }

        if (string.IsNullOrEmpty(time) || string.IsNullOrEmpty(sig1))
            return false;

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_secret));
        var hash = hmac.ComputeHash(
            Encoding.UTF8.GetBytes($"{time}.{requestBody}"));
        var expected = Convert.ToHexStringLower(hash);

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(sig1));
    }
}
