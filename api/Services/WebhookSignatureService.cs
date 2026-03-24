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
        // Fail closed on misconfiguration: reject null, empty, or whitespace values
        // so that HMAC is never computed with a trivially invalid key.
        var secret = configuration["CLOUDFLARE_WEBHOOK_SIGNING_SECRET"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            throw new InvalidOperationException(
                "Required configuration setting "
                + "'CLOUDFLARE_WEBHOOK_SIGNING_SECRET' is missing or empty.");
        }

        _secret = secret;
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

        // Decode the provided signature from hex to bytes so that comparison is
        // case-insensitive and avoids encoding issues.  Reject any sig1 value
        // that is not valid hexadecimal or does not have the expected length.
        byte[] providedSignatureBytes;
        try
        {
            providedSignatureBytes = Convert.FromHexString(sig1);
        }
        catch (FormatException)
        {
            return false;
        }

        if (providedSignatureBytes.Length != hash.Length)
            return false;

        return CryptographicOperations.FixedTimeEquals(hash, providedSignatureBytes);
    }
}
