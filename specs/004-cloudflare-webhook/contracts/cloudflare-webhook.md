# HTTP Contract: Cloudflare Stream → CloudflareWebhook

**Direction**: Inbound — Cloudflare Stream delivers webhook notifications to the CloudflareWebhook function
**Source**: Cloudflare Stream transcoding pipeline
**Transport**: HTTP POST

---

## Endpoint

| Property | Value |
|----------|-------|
| Method | `POST` |
| Route | `/api/webhooks/cloudflare/stream` |
| Authorization Level | `Anonymous` (authentication via HMAC signature) |
| Function Name | `CloudflareWebhook` |

---

## Request

### Headers

| Header | Required | Format | Description |
|--------|----------|--------|-------------|
| `Content-Type` | Yes | `application/json` | Always JSON |
| `Webhook-Signature` | Yes | `time=<UNIX_TIMESTAMP>,sig1=<HEX_SIGNATURE>` | HMAC-SHA256 signature for request validation |

**Signature Header Example**:
```
Webhook-Signature: time=1230811200,sig1=60493ec9388b44585a29543bcf0de62e377d4da393246a8b1c901d0e3e672404
```

### Body — Success Notification

Sent when transcoding completes successfully (`readyToStream: true`, `status.state: "ready"`).

```json
{
  "uid": "dd5d531a12de0c724bd1275a3b2bc9c6",
  "readyToStream": true,
  "status": {
    "state": "ready",
    "pctComplete": "100"
  },
  "meta": {
    "filename": "my-video.mp4",
    "blobpath": "uploads/user123/550e8400-e29b-41d4-a716-446655440000.mp4"
  },
  "duration": 42.5,
  "input": {
    "width": 1920,
    "height": 1080
  },
  "playback": {
    "hls": "https://customer-abc123.cloudflarestream.com/dd5d531a12de0c724bd1275a3b2bc9c6/manifest/video.m3u8",
    "dash": "https://customer-abc123.cloudflarestream.com/dd5d531a12de0c724bd1275a3b2bc9c6/manifest/video.mpd"
  },
  "thumbnail": "https://customer-abc123.cloudflarestream.com/dd5d531a12de0c724bd1275a3b2bc9c6/thumbnails/thumbnail.jpg",
  "created": "2026-03-23T14:30:00.000Z",
  "modified": "2026-03-23T14:32:15.000Z",
  "size": 12345678,
  "preview": "https://watch.cloudflarestream.com/dd5d531a12de0c724bd1275a3b2bc9c6"
}
```

### Body — Error Notification

Sent when transcoding fails (`readyToStream: false`, `status.state: "error"`).

```json
{
  "uid": "dd5d531a12de0c724bd1275a3b2bc9c6",
  "readyToStream": false,
  "status": {
    "state": "error",
    "pctComplete": null,
    "errorReasonCode": "ERR_NON_VIDEO",
    "errorReasonText": "The file was not recognized as a valid video file."
  },
  "meta": {
    "filename": "not-a-video.txt",
    "blobpath": "uploads/user123/550e8400-e29b-41d4-a716-446655440000.txt"
  },
  "duration": 0,
  "input": {
    "width": 0,
    "height": 0
  },
  "playback": null,
  "thumbnail": null,
  "created": "2026-03-23T14:30:00.000Z",
  "modified": "2026-03-23T14:31:05.000Z",
  "size": 1234,
  "preview": null
}
```

---

## Responses

| Scenario | Status Code | Body | Description |
|----------|-------------|------|-------------|
| Valid signature, body parsed | `200 OK` | Empty | Acknowledged; Cloudflare will not retry |
| Missing `Webhook-Signature` header | `401 Unauthorized` | `{ "error": { "code": "MISSING_SIGNATURE", "message": "Missing webhook signature" } }` | Rejected |
| Invalid signature (HMAC mismatch) | `401 Unauthorized` | `{ "error": { "code": "INVALID_SIGNATURE", "message": "Invalid webhook signature" } }` | Rejected |
| Signing secret not configured | N/A | N/A | Unreachable at runtime — `WebhookSignatureService` constructor throws `InvalidOperationException` (fail-closed per FR-011), preventing the Function App from starting |
| Empty or null request body | `400 Bad Request` | `{ "error": { "code": "EMPTY_BODY", "message": "Request body is required" } }` | Rejected |
| Malformed JSON body | `400 Bad Request` | `{ "error": { "code": "INVALID_BODY", "message": "Invalid request body" } }` | Rejected |

---

## Signature Verification Algorithm

1. **Extract** `time` and `sig1` from the `Webhook-Signature` header (split on `,`, then split on `=`)
2. **Construct** source string: `{time}.{raw_request_body}`
3. **Compute** HMAC-SHA256 of the source string using the signing secret
4. **Compare** the computed hex-encoded signature against `sig1` using constant-time comparison

See [research.md — R-001](../research.md#r-001-cloudflare-stream-webhook-signature-verification) for the full C# implementation.

---

## Cloudflare Retry Behavior

| Scenario | Cloudflare Behavior |
|----------|--------------------|
| HTTP 200 response | Delivery succeeds; no retry |
| HTTP 4xx/5xx response | Cloudflare retries up to several times with exponential backoff |
| Timeout (no response) | Cloudflare retries with exponential backoff |

**Note**: Cloudflare does not document exact retry counts or backoff intervals. The function should respond quickly (< 5 seconds per SC-004) to avoid timeouts.

---

## Function Binding

```csharp
[Function(nameof(CloudflareWebhook))]
public async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "webhooks/cloudflare/stream")]
    HttpRequest request,
    CancellationToken cancellationToken)
{
    // 1. Read raw body
    // 2. Verify signature via IWebhookSignatureService
    // 3. Deserialize body to CloudflareWebhookPayload
    // 4. Log video status
    // 5. Return 200 OK
}
```
