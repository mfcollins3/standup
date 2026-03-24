# Research: Cloudflare Stream Webhook Endpoint

**Date**: 2026-03-23

---

## R-001: Cloudflare Stream Webhook Signature Verification

**Decision**: Implement HMAC-SHA256 signature verification using the `Webhook-Signature` header format `time=<UNIX_TIMESTAMP>,sig1=<HEX_SIGNATURE>`.

**Rationale**: Cloudflare Stream signs all webhook notifications with a shared secret using HMAC-SHA256. The signature header includes a timestamp for replay protection and a hex-encoded signature. Verification requires constant-time comparison to prevent timing attacks. All cryptographic primitives are available in the .NET BCL (`System.Security.Cryptography`), so no additional NuGet packages are needed.

**Key Findings**:

- **Header name**: `Webhook-Signature`
- **Header format**: `time=<UNIX_TIMESTAMP>,sig1=<HEX_SIGNATURE>`
- **Example**: `Webhook-Signature: time=1230811200,sig1=60493ec9388b44585a29543bcf0de62e377d4da393246a8b1c901d0e3e672404`

**Verification Algorithm**:

1. **Parse** the `Webhook-Signature` header: split on `,` to get `time` and `sig1` values
2. **Build source string**: concatenate `{time}.{raw_request_body}` — every byte of the body must remain unaltered
3. **Compute expected signature**: `HMAC-SHA256(key=signing_secret, message=source_string)`, encoded as lowercase hex
4. **Compare**: use constant-time comparison (`CryptographicOperations.FixedTimeEquals`) to prevent timing attacks

**C# Implementation Approach**:

```csharp
using System.Security.Cryptography;
using System.Text;

public bool VerifySignature(string signatureHeader, string requestBody, string secret)
{
    // Parse header
    var parts = signatureHeader.Split(',');
    string? time = null;
    string? sig1 = null;
    foreach (var part in parts)
    {
        var kv = part.Split('=', 2);
        if (kv[0] == "time") time = kv[1];
        if (kv[0] == "sig1") sig1 = kv[1];
    }
    if (time is null || sig1 is null) return false;

    // Build source string
    var sourceString = $"{time}.{requestBody}";

    // Compute HMAC-SHA256, hex-encoded
    using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
    var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(sourceString));
    var expectedSignature = Convert.ToHexStringLower(hash);

    // Constant-time comparison
    return CryptographicOperations.FixedTimeEquals(
        Encoding.UTF8.GetBytes(expectedSignature),
        Encoding.UTF8.GetBytes(sig1));
}
```

**Replay Protection**: The `time` field is a UNIX timestamp of when the webhook was sent. Optionally, stale timestamps (e.g., >5 minutes old) can be rejected to mitigate replay attacks. This is a recommended enhancement but not strictly required for initial implementation.

**Fail-Closed Behavior**: Per FR-011, when the signing secret is not configured, all requests must be rejected. The service constructor should validate that the secret is available and throw `InvalidOperationException` if missing, consistent with the pattern used in `CloudflareStreamService.cs`.

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| Third-party webhook verification library | Unnecessary — algorithm is simple (HMAC-SHA256 + hex compare), .NET BCL provides all primitives |
| SHA-512 or other hash algorithm | Cloudflare specifically uses HMAC-SHA256; we must match their implementation |
| String equality comparison (`==`) | Vulnerable to timing attacks; must use `CryptographicOperations.FixedTimeEquals` |

---

## R-002: Cloudflare Stream Webhook Payload Schema

**Decision**: Create a new `CloudflareWebhookPayload` model that captures the full webhook payload. Reuse existing `CloudflareStreamStatus` and `CloudflarePlayback` records from `CloudflareStreamResponse.cs`.

**Rationale**: The webhook payload is a flat JSON object representing a single video (not wrapped in Cloudflare's standard API envelope). The existing `CloudflareStreamResult` model is similar but missing several webhook-specific fields (`meta`, `duration`, `input`, `created`, `modified`, `thumbnail`). A dedicated webhook model provides accurate deserialization without modifying existing API response models.

**Key Findings**:

- **Payload format**: Single JSON object (NOT wrapped in Cloudflare's `{ success, result, errors, messages }` envelope)
- **Content-Type**: `application/json`

**Full Payload Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `uid` | `string` | Video unique identifier (matches UID returned from `/stream/copy`) |
| `readyToStream` | `bool` | `true` when at least one quality level is ready for playback |
| `status` | `object` | Processing status with `state`, `pctComplete`, `errorReasonCode`, `errorReasonText` |
| `meta` | `Dictionary<string, object>` | User-defined metadata attached during upload (e.g., `filename`, `blobpath`) |
| `duration` | `double` | Video duration in seconds |
| `input` | `object` | Source video dimensions (`width`, `height`) |
| `playback` | `object` | Streaming URLs (`hls`, `dash`) — present only when `readyToStream` is `true` |
| `thumbnail` | `string` | Thumbnail image URL |
| `created` | `string` | ISO 8601 creation timestamp |
| `modified` | `string` | ISO 8601 last modified timestamp |
| `size` | `long` | File size in bytes |
| `preview` | `string` | Watch preview URL |

**Status State Values**:

| State | Meaning |
|-------|---------|
| `ready` | Video processing complete, all quality levels encoded |
| `error` | Video processing failed |

**Error Reason Codes**:

| Code | Description |
|------|-------------|
| `ERR_NON_VIDEO` | Upload is not a video |
| `ERR_DURATION_EXCEED_CONSTRAINT` | Duration exceeds constraint |
| `ERR_FETCH_ORIGIN_ERROR` | Failed to download from source URL |
| `ERR_MALFORMED_VIDEO` | Corrupt or unrecoverable video data |
| `ERR_DURATION_TOO_SHORT` | Duration shorter than 0.1 seconds |
| `ERR_UNKNOWN` | Cannot automatically determine error cause |

**Model Reuse Strategy**:

- **Reuse**: `CloudflareStreamStatus` (state, pctComplete, errorReasonCode, errorReasonText) — identical fields
- **Reuse**: `CloudflarePlayback` (hls, dash) — identical fields
- **New**: `CloudflareWebhookPayload` — top-level model for the webhook body
- **New**: `CloudflareVideoInput` — width/height dimensions

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| Reuse `CloudflareStreamResult` directly | Missing `meta`, `duration`, `input`, `created`, `modified`, `thumbnail`, `size` fields needed for logging |
| Deserialize to `JsonDocument` / dynamic | Loses type safety; harder to log structured fields; harder to test |
| Modify existing `CloudflareStreamResult` | Would change the API response model used in `CloudflareStreamService`; webhook payload is structurally different (no envelope) |

---

## R-003: Azure Functions HTTP Trigger for Webhook Endpoint

**Decision**: Use `Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore` with `HttpRequest`/`IActionResult` for the webhook function, matching the pattern established by `CreateVideo.cs`.

**Rationale**: The existing project already uses the ASP.NET Core integration for HTTP-triggered functions. This provides access to `HttpRequest` for reading headers and body, and `IActionResult` for returning typed HTTP responses. The webhook function needs to read the raw request body for signature verification (body bytes must be unaltered).

**Key Findings**:

- **Package**: Already referenced — `Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore` 2.1.0
- **Function attribute**: `[Function(nameof(CloudflareWebhook))]`
- **HTTP method**: POST only
- **Route**: `webhooks/cloudflare/stream` (descriptive, avoids collision with existing endpoints)
- **Authorization level**: `AuthorizationLevel.Anonymous` — signature verification provides authentication; Azure Functions key-based auth is not needed since Cloudflare cannot send function keys

**Raw Body Reading**: The signature verification requires the raw, unaltered request body. Use `HttpRequest.ReadAsStringAsync()` or a `StreamReader` to read the body before any JSON deserialization.

**Response Codes**:

| Scenario | HTTP Status | Body |
|----------|-------------|------|
| Valid signature, successful parse | 200 OK | Empty or minimal acknowledgment |
| Missing/invalid signature | 401 Unauthorized | Error message (no secret details) |
| Missing signing secret config | 401 Unauthorized | Error message (no config details in body) |
| Malformed/empty body | 400 Bad Request | Error message |

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| `AuthorizationLevel.Function` | Cloudflare cannot include Azure Functions keys in webhook calls; HMAC signature provides equivalent security |
| Separate webhook validation middleware | Over-engineering — single endpoint with inline validation is simpler and follows existing patterns |
| API Management policy for signature check | Would require custom C# policy fragment; simpler to implement in the function itself |

---

## R-004: Webhook Signing Secret Configuration

**Decision**: Store the Cloudflare webhook signing secret as an application setting `CLOUDFLARE_WEBHOOK_SIGNING_SECRET`, sourced from Azure Key Vault via the existing Key Vault reference pattern.

**Rationale**: The existing project already stores Cloudflare credentials (`CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`) as app settings referenced from Key Vault. Following the same pattern ensures consistency and leverages the existing infrastructure. The signing secret is provided by Cloudflare when webhooks are configured via the `PUT /stream/webhook` API.

**Key Findings**:

- **Secret source**: Returned in the response when registering the webhook URL via `PUT /accounts/{account_id}/stream/webhook`
- **Secret format**: 32-character hex string (e.g., `85011ed3a913c6ad5f9cf6c5573cc0a7`)
- **Storage**: Azure Key Vault secret, referenced in Function App settings via `@Microsoft.KeyVault(SecretUri=...)`
- **App setting name**: `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` (consistent naming with existing `CLOUDFLARE_*` settings)
- **Local development**: Add to `local.settings.json` under `Values`

**Infrastructure Changes**:

- `key-vault.bicep`: Add new secret for the webhook signing secret
- `function-app.bicep`: Add `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` app setting with Key Vault reference

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| Environment variable without Key Vault | Violates Constitution Principle IV (Security by Default); secrets must be in Key Vault |
| Hardcoded in `local.settings.json` only | Insufficient for deployed environments; need Key Vault for production |
| Separate configuration service | Over-engineering — `IConfiguration` injection is the standard pattern in the existing codebase |
