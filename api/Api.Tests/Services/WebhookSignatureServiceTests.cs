// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using System.Security.Cryptography;
using System.Text;
using Api.Services;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Standup.Api.Tests.Services;

public sealed class WebhookSignatureServiceTests
{
    private const string TestSecret = "test-signing-secret";

    private static WebhookSignatureService CreateService(
        string? secret = TestSecret)
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["CLOUDFLARE_WEBHOOK_SIGNING_SECRET"] = secret
            })
            .Build();
        return new WebhookSignatureService(config);
    }

    private static string ComputeSignature(
        string secret, string timestamp, string body)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var hash = hmac.ComputeHash(
            Encoding.UTF8.GetBytes($"{timestamp}.{body}"));
        return Convert.ToHexStringLower(hash);
    }

    [Fact]
    public void VerifySignature_ValidSignature_ReturnsTrue()
    {
        var service = CreateService();
        const string timestamp = "1230811200";
        const string body = """{"uid":"abc123","readyToStream":true}""";
        var sig = ComputeSignature(TestSecret, timestamp, body);
        var header = $"time={timestamp},sig1={sig}";

        var result = service.VerifySignature(header, body);

        Assert.True(result);
    }

    [Fact]
    public void VerifySignature_InvalidSignature_ReturnsFalse()
    {
        var service = CreateService();
        const string timestamp = "1230811200";
        const string body = """{"uid":"abc123","readyToStream":true}""";
        var header = $"time={timestamp},sig1=0000000000000000000000000000000000000000000000000000000000000000";

        var result = service.VerifySignature(header, body);

        Assert.False(result);
    }

    [Fact]
    public void VerifySignature_WrongSecret_ReturnsFalse()
    {
        var service = CreateService();
        const string timestamp = "1230811200";
        const string body = """{"uid":"abc123","readyToStream":true}""";
        var sig = ComputeSignature("different-secret", timestamp, body);
        var header = $"time={timestamp},sig1={sig}";

        var result = service.VerifySignature(header, body);

        Assert.False(result);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    public void VerifySignature_NullOrEmptyHeader_ReturnsFalse(
        string? signatureHeader)
    {
        var service = CreateService();
        const string body = """{"uid":"abc123","readyToStream":true}""";

        var result = service.VerifySignature(signatureHeader, body);

        Assert.False(result);
    }

    [Fact]
    public void VerifySignature_MalformedHeader_MissingTime_ReturnsFalse()
    {
        var service = CreateService();
        const string body = """{"uid":"abc123","readyToStream":true}""";
        var header = "sig1=abc123def456";

        var result = service.VerifySignature(header, body);

        Assert.False(result);
    }

    [Fact]
    public void VerifySignature_MalformedHeader_MissingSig1_ReturnsFalse()
    {
        var service = CreateService();
        const string body = """{"uid":"abc123","readyToStream":true}""";
        var header = "time=1230811200";

        var result = service.VerifySignature(header, body);

        Assert.False(result);
    }

    [Fact]
    public void VerifySignature_EmptyBody_ReturnsFalse()
    {
        var service = CreateService();
        var timestamp = "1230811200";
        var sig = ComputeSignature(TestSecret, timestamp, "");
        var header = $"time={timestamp},sig1={sig}";

        var result = service.VerifySignature(header, "");

        Assert.False(result);
    }

    [Fact]
    public void Constructor_MissingSigningSecret_ThrowsInvalidOperationException()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>())
            .Build();

        Assert.Throws<InvalidOperationException>(
            () => new WebhookSignatureService(config));
    }
}
