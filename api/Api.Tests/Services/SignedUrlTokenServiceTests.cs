// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Security.Cryptography;
using System.Text.Json;
using Api.Models;
using Api.Services;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Standup.Api.Tests.Services;

public sealed class SignedUrlTokenServiceTests
{
    private const string TestKeyId = "test-key-id";
    private const string TestCustomerCode = "abc12345";

    private static (IConfiguration Config, RSA Rsa) BuildTestConfiguration(
        string? overrideSigningKeyJwk = null,
        string? overrideSigningKeyId = null,
        string? overrideCustomerCode = null)
    {
        var rsa = RSA.Create(2048);
        string actualJwk;

        if (overrideSigningKeyJwk is not null)
        {
            actualJwk = overrideSigningKeyJwk;
        }
        else
        {
            var parameters = rsa.ExportParameters(includePrivateParameters: true);
            var jwkObject = new
            {
                kty = "RSA",
                n = Base64UrlEncode(parameters.Modulus!),
                e = Base64UrlEncode(parameters.Exponent!),
                d = Base64UrlEncode(parameters.D!),
                p = Base64UrlEncode(parameters.P!),
                q = Base64UrlEncode(parameters.Q!),
                dp = Base64UrlEncode(parameters.DP!),
                dq = Base64UrlEncode(parameters.DQ!),
                qi = Base64UrlEncode(parameters.InverseQ!)
            };
            actualJwk = Convert.ToBase64String(
                System.Text.Encoding.UTF8.GetBytes(JsonSerializer.Serialize(jwkObject)));
        }

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_SIGNING_KEY_JWK"] = actualJwk,
                ["CLOUDFLARE_SIGNING_KEY_ID"] = overrideSigningKeyId ?? TestKeyId,
                ["CLOUDFLARE_CUSTOMER_CODE"] = overrideCustomerCode ?? TestCustomerCode
            })
            .Build();

        return (config, rsa);
    }

    private static string Base64UrlEncode(byte[] data)
    {
        return Convert.ToBase64String(data)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    [Fact]
    public async Task GenerateSignedUrlAsync_HlsStreamType_ReturnsHlsManifestUrl()
    {
        var (config, rsa) = BuildTestConfiguration();
        using (rsa)
        {
            var service = new SignedUrlTokenService(config);

            var result = await service.GenerateSignedUrlAsync("videoid", StreamType.Hls);

            Assert.NotNull(result);
            Assert.Contains($"customer-{TestCustomerCode}.cloudflarestream.com", result.SignedUrl);
            Assert.EndsWith("/manifest/video.m3u8", result.SignedUrl);
        }
    }

    [Fact]
    public async Task GenerateSignedUrlAsync_DashStreamType_ReturnsDashManifestUrl()
    {
        var (config, rsa) = BuildTestConfiguration();
        using (rsa)
        {
            var service = new SignedUrlTokenService(config);

            var result = await service.GenerateSignedUrlAsync("videoid", StreamType.Dash);

            Assert.NotNull(result);
            Assert.Contains($"customer-{TestCustomerCode}.cloudflarestream.com", result.SignedUrl);
            Assert.EndsWith("/manifest/video.mpd", result.SignedUrl);
        }
    }

    [Fact]
    public async Task GenerateSignedUrlAsync_TokenExpiresInOneHour()
    {
        var (config, rsa) = BuildTestConfiguration();
        using (rsa)
        {
            var service = new SignedUrlTokenService(config);
            var before = DateTimeOffset.UtcNow.AddMinutes(59);

            var result = await service.GenerateSignedUrlAsync("somevideouid", StreamType.Hls);

            var after = DateTimeOffset.UtcNow.AddMinutes(61);
            Assert.True(
                result.ExpiresAt >= before,
                $"ExpiresAt {result.ExpiresAt} should be >= {before}");
            Assert.True(
                result.ExpiresAt <= after,
                $"ExpiresAt {result.ExpiresAt} should be <= {after}");
        }
    }

    [Fact]
    public async Task GenerateSignedUrlAsync_TokenContainsVideoUidAsSubClaim()
    {
        var (config, rsa) = BuildTestConfiguration();
        using (rsa)
        {
            var service = new SignedUrlTokenService(config);
            const string videoUid = "expectedVideoUid";

            var result = await service.GenerateSignedUrlAsync(videoUid, StreamType.Hls);

            // URL format: https://customer-xxx.cloudflarestream.com/{token}/manifest/video.m3u8
            var urlParts = result.SignedUrl.Split('/');
            var token = urlParts[3];
            var tokenParts = token.Split('.');
            Assert.Equal(3, tokenParts.Length);

            var payloadJson = System.Text.Encoding.UTF8.GetString(
                Convert.FromBase64String(PadBase64(tokenParts[1])));
            using var doc = JsonDocument.Parse(payloadJson);
            var sub = doc.RootElement.GetProperty("sub").GetString();
            Assert.Equal(videoUid, sub);
        }
    }

    [Fact]
    public async Task GenerateSignedUrlAsync_TokenHeaderContainsRS256AlgorithmAndKeyId()
    {
        var (config, rsa) = BuildTestConfiguration();
        using (rsa)
        {
            var service = new SignedUrlTokenService(config);

            var result = await service.GenerateSignedUrlAsync("videoid", StreamType.Hls);

            var urlParts = result.SignedUrl.Split('/');
            var token = urlParts[3];
            var headerJson = System.Text.Encoding.UTF8.GetString(
                Convert.FromBase64String(PadBase64(token.Split('.')[0])));
            using var doc = JsonDocument.Parse(headerJson);
            Assert.Equal("RS256", doc.RootElement.GetProperty("alg").GetString());
            Assert.Equal(TestKeyId, doc.RootElement.GetProperty("kid").GetString());
        }
    }

    [Fact]
    public async Task GenerateSignedUrlAsync_JwtExpClaimMatchesExpiresAt()
    {
        var (config, rsa) = BuildTestConfiguration();
        using (rsa)
        {
            var service = new SignedUrlTokenService(config);

            var result = await service.GenerateSignedUrlAsync("videoid", StreamType.Hls);

            // Extract JWT exp claim from token payload
            var token = result.SignedUrl.Split('/')[3];
            var payloadJson = System.Text.Encoding.UTF8.GetString(
                Convert.FromBase64String(PadBase64(token.Split('.')[1])));
            using var doc = JsonDocument.Parse(payloadJson);
            var expUnix = doc.RootElement.GetProperty("exp").GetInt64();
            var expFromToken = DateTimeOffset.FromUnixTimeSeconds(expUnix);

            // Allow ±2 second tolerance between the JWT exp claim and the
            // returned ExpiresAt (they should be identical but clocks round)
            var delta = Math.Abs((expFromToken - result.ExpiresAt).TotalSeconds);
            Assert.True(delta <= 2,
                $"JWT exp claim ({expFromToken}) should match ExpiresAt ({result.ExpiresAt}) within 2 seconds");
        }
    }

    [Fact]
    public void Constructor_MissingSigningKeyId_ThrowsInvalidOperationException()    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_SIGNING_KEY_JWK"] = "anyjwkvalue",
                ["CLOUDFLARE_CUSTOMER_CODE"] = TestCustomerCode
            })
            .Build();

        var exception = Assert.Throws<InvalidOperationException>(
            () => new SignedUrlTokenService(config));
        Assert.Contains("CLOUDFLARE_SIGNING_KEY_ID", exception.Message);
    }

    [Fact]
    public void Constructor_MissingSigningKeyJwk_ThrowsInvalidOperationException()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_SIGNING_KEY_ID"] = TestKeyId,
                ["CLOUDFLARE_CUSTOMER_CODE"] = TestCustomerCode
            })
            .Build();

        var exception = Assert.Throws<InvalidOperationException>(
            () => new SignedUrlTokenService(config));
        Assert.Contains("CLOUDFLARE_SIGNING_KEY_JWK", exception.Message);
    }

    [Fact]
    public void Constructor_MissingCustomerCode_ThrowsInvalidOperationException()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_SIGNING_KEY_ID"] = TestKeyId,
                ["CLOUDFLARE_SIGNING_KEY_JWK"] = "anyjwkvalue"
            })
            .Build();

        var exception = Assert.Throws<InvalidOperationException>(
            () => new SignedUrlTokenService(config));
        Assert.Contains("CLOUDFLARE_CUSTOMER_CODE", exception.Message);
    }

    private static string PadBase64(string base64Url)
    {
        var base64 = base64Url.Replace('-', '+').Replace('_', '/');
        return (base64.Length % 4) switch
        {
            2 => base64 + "==",
            3 => base64 + "=",
            _ => base64
        };
    }
}
