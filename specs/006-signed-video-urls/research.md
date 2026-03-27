# Research: Signed Video URLs for Secure Streaming

**Date**: 2026-03-26
**Feature**: [spec.md](spec.md) | [plan.md](plan.md)

## R1: Cloudflare Stream Signed URL Token Generation

### Decision: Use a self-signing key (Option 2) to generate RS256 JWT tokens locally

### Rationale

Cloudflare offers two approaches for generating signed URL tokens:

1. **`/token` endpoint** — Call the Cloudflare API for each token. Simple but limited to ~1,000 tokens/day due to API rate limits. Requires a network call for every playback request. Does not support Live WebRTC.

2. **Signing key (recommended)** — Call the `/stream/key` endpoint once to obtain a key ID (`kid`) and a private key (`pem` or `jwk`). Generate RS256 JWT tokens locally without any Cloudflare API calls. Supports unlimited tokens, no rate limits, and all playback modes.

Option 2 is the Cloudflare-recommended approach. It eliminates a network dependency at playback time, has no rate limits, and produces tokens faster (local crypto vs. HTTPS round-trip). The signing key is obtained once and stored securely.

### Alternatives Considered

- **Option 1 (`/token` endpoint)**: Simpler initial setup (no key management) but imposes a hard rate limit. For a team standup product with many daily viewings, this could become a bottleneck. Also adds latency to every playback request. Rejected.

### Key Implementation Details

- **Key provisioning**: Call `POST /stream/key` once to get `id` (key ID) and `pem`/`jwk` (private key, base64-encoded). Store both in Key Vault.
- **Token format**: RS256 JWT with header `{ "alg": "RS256", "kid": "<KEY_ID>" }` and payload `{ "sub": "<VIDEO_UID>", "kid": "<KEY_ID>", "exp": <UNIX_TIMESTAMP> }`.
- **Signed URL format**: Replace the video UID in the manifest URL with the signed token: `https://customer-<CODE>.cloudflarestream.com/<TOKEN>/manifest/video.m3u8` (HLS) or `video.mpd` (DASH).
- **Token lifetime**: Max 24 hours from when the token is signed. Default to 1 hour.
- **Key revocation**: Keys can be revoked via `DELETE /stream/key/<KEY_ID>`. After revocation, all tokens signed with that key become invalid.

---

## R2: Enabling `requireSignedURLs` on Videos

### Decision: Set `requireSignedURLs: true` in the Cloudflare `/stream/copy` request body when submitting videos for transcoding

### Rationale

The `CloudflareStreamRequest` model already has a `RequireSignedURLs` property (added as nullable bool). Setting this to `true` during the `/stream/copy` call ensures every video is locked down from the moment it enters Cloudflare. This is simpler and more secure than updating videos after upload.

### Alternatives Considered

- **Update videos after upload via PATCH**: Would require an additional API call and creates a window where the video is publicly accessible between upload and the PATCH. Rejected — setting the flag at submission time is simpler and more secure.
- **Set via tus upload metadata**: The `requiresignedurls` metadata key can be set during tus uploads. Not applicable here because the current pipeline uses `/stream/copy` (URL-based upload from blob storage SAS URL).

### Key Implementation Details

- Modify `CloudflareStreamService.SubmitForTranscodingAsync` to always pass `RequireSignedURLs = true` in the request body.
- The `CloudflareStreamRequest` record already has the property: `[property: JsonPropertyName("requireSignedURLs")] bool? RequireSignedURLs = null`. Just pass `true`.
- Once set, public URLs like `customer-<CODE>.cloudflarestream.com/<VIDEO_UID>/watch` and direct manifest URLs will return errors without a valid signed token.

---

## R3: JWT Generation in .NET

### Decision: Use `System.IdentityModel.Tokens.Jwt` (Microsoft's JWT library) with `RSA` for RS256 signing

### Rationale

The `System.IdentityModel.Tokens.Jwt` NuGet package is the standard Microsoft library for JWT creation and validation in .NET. It supports RS256 natively with `RsaSecurityKey` and `SigningCredentials`. The Cloudflare signing key is provided as a base64-encoded PEM or JWK — both can be imported into an `RSA` instance.

### Alternatives Considered

- **Manual JWT construction**: Build the JWT header/payload/signature by hand using `System.Security.Cryptography.RSA`. Works but is error-prone and reinvents what a well-tested library already provides. Rejected.
- **jose-jwt or other third-party libraries**: Viable but adds a dependency when the Microsoft library already handles this case. Rejected in favor of the standard library.

### Key Implementation Details

- Add `System.IdentityModel.Tokens.Jwt` NuGet package to `Api.csproj`.
- The signing key PEM from Cloudflare must be base64-decoded, then imported into an `RSA` instance via `RSA.ImportFromPem()` (available in .NET 5+).
- Create a `JwtSecurityToken` with the required claims (`sub`, `kid`, `exp`) and sign with `SigningCredentials(rsaKey, SecurityAlgorithms.RsaSha256)`.
- Serialize using `JwtSecurityTokenHandler.WriteToken()`.

---

## R4: Cloudflare Customer Code for Manifest URLs

### Decision: Store the Cloudflare customer subdomain code as a configuration value

### Rationale

Cloudflare Stream manifest URLs follow the pattern: `https://customer-<CODE>.cloudflarestream.com/<TOKEN>/manifest/video.m3u8`. The `<CODE>` is a unique customer-specific subdomain assigned by Cloudflare that does not change. This value is needed to construct the signed manifest URL.

### Alternatives Considered

- **Extract from stored HLS/DASH URLs**: The `Video` entity already stores HLS and DASH URLs from Cloudflare webhook notifications. We could parse the customer code from these URLs at runtime. However, this adds parsing complexity and fails for videos that don't yet have stored URLs. Rejected.
- **Hardcode in source**: Violates the principle of keeping configuration external. Rejected.

### Key Implementation Details

- Store as the `CLOUDFLARE_CUSTOMER_CODE` environment variable / app setting.
- Add to Key Vault or app configuration as appropriate (not secret, but environment-specific).
- The service uses this value to construct: `https://customer-{code}.cloudflarestream.com/{token}/manifest/video.{m3u8|mpd}`.

---

## R5: Key Storage in Azure Key Vault

### Decision: Store the Cloudflare signing key ID and private key (JWK) as Key Vault secrets

### Rationale

The constitution mandates that secrets must be stored in Azure Key Vault. The Cloudflare signing key consists of two parts: a key ID (`kid`) and a private key (JWK or PEM format). Both must be stored securely and accessible to the Function App via managed identity.

### Key Implementation Details

- Two new Key Vault secrets: `CloudflareSigningKeyId` and `CloudflareSigningKeyJwk`.
- The Function App already has Key Vault Secrets Officer role (set up in previous features).
- App settings reference Key Vault secrets using the `@Microsoft.KeyVault(SecretUri=...)` syntax or the Function App reads them directly via the Azure SDK.
- For local development, use User Secrets (`dotnet user-secrets`) to provide the signing key values.
- Bicep updates to `key-vault.bicep` to define the new secret resources (values provided as secure parameters at deployment time).

---

## R6: APIM Operation for the New Endpoint

### Decision: Add a new GET operation to the existing APIM `standup-api` API

### Rationale

All existing API endpoints (e.g., `POST /video`) are exposed through Azure API Management. The new `GetSignedStreamUrl` function must follow the same pattern for consistency, security (subscription key validation), and observability (APIM logging/diagnostics).

### Key Implementation Details

- New APIM operation: `GET /video/{videoId}/stream` with a required `streamType` query parameter.
- Added to `api-management.bicep` following the existing `createVideoOperation` pattern.
- The operation uses the same backend (`standup-api-backend`) and inherits the API-level policy (function key authentication, subscription key validation).
- Template parameter `videoId` with type `string`.
