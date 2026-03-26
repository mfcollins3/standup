# Contract Changes: CloudflareWebhook Endpoint

**Feature**: 005 — Video Tracking and Persistence
**Direction**: Inbound — Cloudflare Stream → CloudflareWebhook function
**Change Type**: Database side effects added (external HTTP contract unchanged)

---

## Endpoint (Unchanged)

| Property | Value |
|----------|-------|
| Method | `POST` |
| Route | `/api/webhooks/cloudflare/stream` |
| Authorization Level | `Anonymous` |
| Function Name | `CloudflareWebhook` |

---

## Request (Unchanged)

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Webhook-Signature` | Yes | HMAC-SHA256 signature for payload verification |
| `Content-Type` | Yes | `application/json` |

### Body

The CloudflareWebhookPayload structure is unchanged. See Feature 004 contract.

---

## Response (Unchanged)

| Scenario | Status | Body |
|----------|--------|------|
| Valid signature, processed | `200 OK` | Empty |
| Missing signature header | `400 Bad Request` | Error JSON |
| Invalid signature | `401 Unauthorized` | Error JSON |
| Deserialization failure | `400 Bad Request` | Error JSON |

---

## Side Effects — New

### On Valid Webhook Received

The webhook uses a two-tier lookup strategy to find the Video record:

| Priority | Lookup Method | Description |
|----------|--------------|-------------|
| 1 (Primary) | `payload.Meta["videoId"]` | Direct primary key lookup by `Video.Id`. The `videoId` is round-tripped through Cloudflare's meta dictionary, set by ProcessVideo when submitting to `/stream/copy`. |
| 2 (Fallback) | `payload.Uid` → `cloudflare_video_uid` | Index lookup by Cloudflare's UID. Used if `videoId` is missing from meta (e.g., videos submitted before this enhancement, or if meta is null). |

| Action | Description |
|--------|-------------|
| Validation | If no matching Video record is found by either lookup, log a warning and return `200 OK` (acknowledge to prevent Cloudflare retries) |

### When `readyToStream` Is True

| Field Updated | Source |
|--------------|--------|
| `status` | → `ready` |
| `hls_url` | `payload.Playback.Hls` |
| `dash_url` | `payload.Playback.Dash` |
| `thumbnail_url` | `payload.Thumbnail` |
| `duration` | `payload.Duration` |
| `input_width` | `payload.Input.Width` |
| `input_height` | `payload.Input.Height` |
| `updated_at` | Current UTC timestamp |

### When `readyToStream` Is False and Status Indicates Error

| Field Updated | Source |
|--------------|--------|
| `status` | → `failed` |
| `error_reason_code` | `payload.Status.ErrorReasonCode` |
| `error_reason_text` | `payload.Status.ErrorReasonText` |
| `updated_at` | Current UTC timestamp |

---

## State Transitions

```text
Video.Status:  processing  ──►  ready    (readyToStream == true)
                           ──►  failed   (error in status)
```

---

## Error Handling

| Scenario | Database Action | HTTP Response |
|----------|----------------|---------------|
| No Video found by meta videoId or Cloudflare UID | None (log warning) | `200 OK` |
| Database unavailable | None (log error) | `200 OK` (acknowledge webhook) |
| Duplicate webhook (Video already `ready`) | Idempotent update | `200 OK` |
| Meta dictionary is null or missing `videoId` | Fallback to `cloudflare_video_uid` lookup | `200 OK` |
