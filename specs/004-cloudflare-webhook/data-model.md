# Data Model: Cloudflare Stream Webhook Endpoint

**Date**: 2026-03-23
**Phase**: 1 — Design & Contracts

---

## Entities

### CloudflareWebhookPayload (New — `api/Models/`)

Top-level model for the Cloudflare Stream webhook request body. This is a flat JSON object representing a single video — it is NOT wrapped in the Cloudflare API envelope (`{ success, result, errors, messages }`).

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Uid` | `string` | `uid` | Cloudflare Stream video identifier |
| `ReadyToStream` | `bool` | `readyToStream` | `true` when at least one quality level is playable |
| `Status` | `CloudflareStreamStatus?` | `status` | Processing status (reused from existing model) |
| `Meta` | `Dictionary<string, object>?` | `meta` | User-defined metadata (e.g., `filename`, `blobpath`) |
| `Duration` | `double?` | `duration` | Video duration in seconds |
| `Input` | `CloudflareVideoInput?` | `input` | Source video dimensions |
| `Playback` | `CloudflarePlayback?` | `playback` | HLS/DASH playback URLs (reused from existing model) |
| `Thumbnail` | `string?` | `thumbnail` | Thumbnail image URL |
| `Created` | `string?` | `created` | ISO 8601 creation timestamp |
| `Modified` | `string?` | `modified` | ISO 8601 last modified timestamp |
| `Size` | `long?` | `size` | File size in bytes |
| `Preview` | `string?` | `preview` | Watch preview URL |

**Validation Rules (applied by CloudflareWebhook function)**:
- `Uid` may be null or empty. When absent, the function logs a warning and continues processing (per edge case EC-6: unknown video UID).
- `Status` is checked when `ReadyToStream` is `false` to determine error vs. in-progress states.

**Model Reuse**:
- `CloudflareStreamStatus` — reused directly (fields: `State`, `PctComplete`, `ErrorReasonCode`, `ErrorReasonText`)
- `CloudflarePlayback` — reused directly (fields: `Hls`, `Dash`)

---

### CloudflareVideoInput (New — `api/Models/`)

Dimensions of the source video, included in the webhook payload.

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Width` | `int?` | `width` | Source video width in pixels |
| `Height` | `int?` | `height` | Source video height in pixels |

---

### IWebhookSignatureService (New — `api/Services/`)

Interface for webhook signature verification. Extracted as an interface for testability via dependency injection.

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `VerifySignature` | `string? signatureHeader`, `string requestBody` | `bool` | Parses the `Webhook-Signature` header, computes HMAC-SHA256, and performs constant-time comparison. Accepts nullable `signatureHeader` so callers do not need to null-check before calling. |

---

### WebhookSignatureService (New — `api/Services/`)

Implementation of `IWebhookSignatureService`. Reads the signing secret from `IConfiguration["CLOUDFLARE_WEBHOOK_SIGNING_SECRET"]`.

**Constructor Dependencies**:

| Dependency | Type | Description |
|-----------|------|-------------|
| `configuration` | `IConfiguration` | Used to read `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` |

**Validation Rules**:
- Constructor throws `InvalidOperationException` if `CLOUDFLARE_WEBHOOK_SIGNING_SECRET` is null or empty (fail-closed per FR-011).

**Algorithm**: See [research.md — R-001](research.md#r-001-cloudflare-stream-webhook-signature-verification) for full implementation details.

---

## Existing Models Referenced

### CloudflareStreamStatus (Existing — `api/Models/CloudflareStreamResponse.cs`)

Reused without modification for the webhook payload `status` field.

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `State` | `string` | `state` | Processing state: `ready`, `error` (webhook only fires on terminal states) |
| `PctComplete` | `string?` | `pctComplete` | Always `"100"` for `ready` or `null` for `error` |
| `ErrorReasonCode` | `string?` | `errorReasonCode` | Error code if `State` is `error` |
| `ErrorReasonText` | `string?` | `errorReasonText` | Human-readable error description |

### CloudflarePlayback (Existing — `api/Models/CloudflareStreamResponse.cs`)

Reused without modification for the webhook payload `playback` field.

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Hls` | `string?` | `hls` | HLS manifest URL |
| `Dash` | `string?` | `dash` | DASH manifest URL |

---

## Relationships

```
Feature 003: ProcessVideo
       │
       │ submits video URL to Cloudflare Stream
       ▼
Cloudflare Stream ── transcodes video ── fires webhook ──▶ CloudflareWebhook Function
       │                                                          │
       │ payload: CloudflareWebhookPayload                        │
       │ header: Webhook-Signature                                │
       ◀──────────────────────────────────────────────────────────┘
                                                                  │
                                              WebhookSignatureService
                                              verifies HMAC-SHA256
                                                                  │
                                              Log video uid, status,
                                              readyToStream, error codes
```

- A single **Cloudflare Stream video** produces one or more webhook notifications (typically one `ready` or one `error`).
- The **CloudflareWebhook function** does not persist any data — it logs and acknowledges (persistence is deferred to a future feature).
- The **meta** dictionary can be used to correlate the webhook notification back to the original blob upload (e.g., `blobpath` set during `ProcessVideo`).
