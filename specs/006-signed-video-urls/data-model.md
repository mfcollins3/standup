# Data Model: Signed Video URLs for Secure Streaming

**Date**: 2026-03-26
**Feature**: [spec.md](spec.md) | [plan.md](plan.md)

## Existing Entities (no schema changes)

### Video (unchanged)

The `Video` entity already contains all fields needed for signed URL generation. No database migration is required for this feature.

| Field | Type | Purpose for This Feature |
|-------|------|-------------------------|
| `Id` | `Guid` | Primary key — used as the API input parameter to identify which video to generate a signed URL for. |
| `CloudflareVideoUid` | `string?` | The Cloudflare Stream video UID — used as the `sub` claim in the signed JWT token. |
| `Status` | `VideoStatus` | Must be `Ready` before a signed URL can be generated. Used for validation. |
| `HlsUrl` | `string?` | Stored HLS manifest URL from Cloudflare. Not used directly for signed URLs (URL is constructed from token + customer code). |
| `DashUrl` | `string?` | Stored DASH manifest URL from Cloudflare. Not used directly for signed URLs. |

### VideoStatus (unchanged)

```
Created = 0 → Uploaded = 1 → Processing = 2 → Ready = 3
                                              → Failed = 4
```

Only videos with `Status = Ready` are eligible for signed URL generation.

## New Value Objects (in-memory only, no persistence)

### SignedStreamUrlResult

Returned by `ISignedUrlTokenService`. Contains the constructed signed manifest URL and its expiration time.

| Property | Type | Description |
|----------|------|-------------|
| `SignedUrl` | `string` | The full signed manifest URL: `https://customer-{code}.cloudflarestream.com/{token}/manifest/video.{m3u8\|mpd}` |
| `ExpiresAt` | `DateTimeOffset` | When the signed token expires. |

### StreamType (enum)

Represents the supported stream manifest formats.

| Value | Description |
|-------|-------------|
| `Hls` | HLS manifest (`video.m3u8`) |
| `Dash` | DASH manifest (`video.mpd`) |

## Configuration Values (not persisted in database)

| Setting | Source | Description |
|---------|--------|-------------|
| `CLOUDFLARE_SIGNING_KEY_ID` | Key Vault secret | The `kid` from the Cloudflare `/stream/key` endpoint. Used in the JWT header. |
| `CLOUDFLARE_SIGNING_KEY_JWK` | Key Vault secret | The JWK-format private key from Cloudflare. Used to sign RS256 tokens. |
| `CLOUDFLARE_CUSTOMER_CODE` | App setting | The customer-specific subdomain code for constructing manifest URLs. |

## Relationships

```
Video (existing) --[CloudflareVideoUid]--> Cloudflare Stream Video
                                           └── requireSignedURLs: true (set at upload time)

Signing Key (Key Vault) --[kid + jwk]--> JWT Token (in-memory)
                                          └── sub: CloudflareVideoUid
                                          └── exp: now + 1 hour
                                          └── kid: signing key ID

JWT Token + Customer Code --> Signed Manifest URL
                              └── HLS: customer-{code}.cloudflarestream.com/{token}/manifest/video.m3u8
                              └── DASH: customer-{code}.cloudflarestream.com/{token}/manifest/video.mpd
```
