// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Text.Json;
using Api.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Api.Services;

public sealed class SignedUrlTokenService : ISignedUrlTokenService
{
    private readonly string _signingKeyId;
    private readonly string _customerCode;
    private readonly SigningCredentials _signingCredentials;

    public SignedUrlTokenService(IConfiguration configuration)
    {
        _signingKeyId = configuration["CLOUDFLARE_SIGNING_KEY_ID"]
            ?? throw new InvalidOperationException(
                "Required setting 'CLOUDFLARE_SIGNING_KEY_ID' is not configured.");

        var signingKeyJwk = configuration["CLOUDFLARE_SIGNING_KEY_JWK"]
            ?? throw new InvalidOperationException(
                "Required setting 'CLOUDFLARE_SIGNING_KEY_JWK' is not configured.");

        _customerCode = configuration["CLOUDFLARE_CUSTOMER_CODE"]
            ?? throw new InvalidOperationException(
                "Required setting 'CLOUDFLARE_CUSTOMER_CODE' is not configured.");

        // Decode the base64-encoded JWK JSON and import RSA private key.
        // Key material is read once at startup and stored as signing credentials.
        var jwkJson = System.Text.Encoding.UTF8.GetString(
            Convert.FromBase64String(signingKeyJwk));

        var rsa = RSA.Create();
        rsa.ImportParameters(ParseRsaParametersFromJwk(jwkJson));
        var rsaSecurityKey = new RsaSecurityKey(rsa) { KeyId = _signingKeyId };
        _signingCredentials = new SigningCredentials(rsaSecurityKey, SecurityAlgorithms.RsaSha256);
    }

    public Task<SignedStreamUrlResult> GenerateSignedUrlAsync(
        string cloudflareVideoUid,
        StreamType streamType,
        CancellationToken cancellationToken = default)
    {
        var expiresAt = DateTimeOffset.UtcNow.AddHours(1);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Claims = new Dictionary<string, object>
            {
                ["sub"] = cloudflareVideoUid,
                ["kid"] = _signingKeyId
            },
            Expires = expiresAt.UtcDateTime,
            SigningCredentials = _signingCredentials
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        var tokenString = tokenHandler.WriteToken(token);

        var extension = streamType == StreamType.Hls ? "m3u8" : "mpd";
        var signedUrl =
            $"https://customer-{_customerCode}.cloudflarestream.com" +
            $"/{tokenString}/manifest/video.{extension}";

        return Task.FromResult(new SignedStreamUrlResult(signedUrl, expiresAt));
    }

    private static RSAParameters ParseRsaParametersFromJwk(string jwkJson)
    {
        using var doc = JsonDocument.Parse(jwkJson);
        var root = doc.RootElement;
        return new RSAParameters
        {
            Modulus = Base64UrlDecodeBytes(root.GetProperty("n").GetString()!),
            Exponent = Base64UrlDecodeBytes(root.GetProperty("e").GetString()!),
            D = Base64UrlDecodeBytes(root.GetProperty("d").GetString()!),
            P = Base64UrlDecodeBytes(root.GetProperty("p").GetString()!),
            Q = Base64UrlDecodeBytes(root.GetProperty("q").GetString()!),
            DP = Base64UrlDecodeBytes(root.GetProperty("dp").GetString()!),
            DQ = Base64UrlDecodeBytes(root.GetProperty("dq").GetString()!),
            InverseQ = Base64UrlDecodeBytes(root.GetProperty("qi").GetString()!)
        };
    }

    private static byte[] Base64UrlDecodeBytes(string base64Url)
    {
        var base64 = base64Url.Replace('-', '+').Replace('_', '/');
        return (base64.Length % 4) switch
        {
            2 => Convert.FromBase64String(base64 + "=="),
            3 => Convert.FromBase64String(base64 + "="),
            _ => Convert.FromBase64String(base64)
        };
    }
}
