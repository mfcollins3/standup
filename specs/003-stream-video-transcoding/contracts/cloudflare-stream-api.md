# API Contract: Cloudflare Stream — Upload from URL

**Base URL**: `https://api.cloudflare.com/client/v4/accounts/{account_id}`
**Authentication**: Bearer token via `Authorization` header (API Token with "Stream Write" permission)
**Direction**: Consumed by ProcessVideo function (server-to-server)

---

## POST /stream/copy

Submit a video URL for transcoding and on-demand streaming delivery.

### Request

**Headers**:

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <API_TOKEN>` — Cloudflare API token with Stream Write permission |
| `Content-Type` | Yes | `application/json` |

**Body** (`application/json`):

```json
{
  "url": "https://ststandup.blob.core.windows.net/status-videos/uploads/anonymous/550e8400-e29b-41d4-a716-446655440000.mp4?sv=2024-11-04&st=...&se=...&sr=b&sp=r&sig=...",
  "meta": {
    "blobPath": "uploads/anonymous/550e8400-e29b-41d4-a716-446655440000.mp4"
  },
  "requireSignedURLs": false
}
```

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `url` | `string` | Yes | Valid HTTPS URL; must support HEAD and GET range requests | Source video URL (our read SAS URL) |
| `meta` | `object` | No | Keys and values must be strings | Arbitrary metadata stored with the video; we include `blobPath` to correlate back to the source blob |
| `requireSignedURLs` | `boolean` | No | Default: `false` | Whether playback URLs require signed tokens |

### Response

**200 OK** (`application/json`):

```json
{
  "result": {
    "uid": "ea95132c15732412d22c1476fa83f27a",
    "status": {
      "state": "downloading",
      "pctComplete": "0.000000",
      "errorReasonCode": "",
      "errorReasonText": ""
    },
    "playback": {
      "hls": "https://customer-abcdefgh.cloudflarestream.com/ea95132c15732412d22c1476fa83f27a/manifest/video.m3u8",
      "dash": "https://customer-abcdefgh.cloudflarestream.com/ea95132c15732412d22c1476fa83f27a/manifest/video.mpd"
    },
    "readyToStream": false,
    "meta": {
      "blobPath": "uploads/anonymous/550e8400-e29b-41d4-a716-446655440000.mp4"
    }
  },
  "success": true,
  "errors": [],
  "messages": []
}
```

| Field | Type | Description |
|-------|------|-------------|
| `result.uid` | `string` | Unique video identifier assigned by Cloudflare; used for status checks and playback |
| `result.status.state` | `string` | Current processing state: `downloading`, `queued`, `inprogress`, `ready`, `error` |
| `result.status.pctComplete` | `string` | Encoding progress as a decimal string (e.g., `"50.000000"`) |
| `result.status.errorReasonCode` | `string` | Error code if `state` is `error`; empty otherwise |
| `result.status.errorReasonText` | `string` | Human-readable error description if `state` is `error` |
| `result.playback.hls` | `string` | HLS manifest URL (available regardless of processing state) |
| `result.playback.dash` | `string` | DASH manifest URL (available regardless of processing state) |
| `result.readyToStream` | `boolean` | `true` when the video is ready for playback |
| `result.meta` | `object` | Metadata provided in the request |
| `success` | `boolean` | `true` if the request was accepted |
| `errors` | `array` | Empty on success; contains error objects on failure |
| `messages` | `array` | Informational messages from the API |

### Error Responses

**400 Bad Request** — Invalid request body or missing required fields:

```json
{
  "result": null,
  "success": false,
  "errors": [{ "code": 10005, "message": "Could not process request body" }],
  "messages": []
}
```

**401 Unauthorized** — Missing or invalid API token:

```json
{
  "result": null,
  "success": false,
  "errors": [{ "code": 10000, "message": "Authentication error" }],
  "messages": []
}
```

**429 Too Many Requests** — Rate limit exceeded (>120 concurrent encoding jobs or >1200 requests per 5 minutes):

```json
{
  "result": null,
  "success": false,
  "errors": [{ "code": 10004, "message": "Too many requests" }],
  "messages": []
}
```

**500 Internal Server Error** — Cloudflare server-side failure:

```json
{
  "result": null,
  "success": false,
  "errors": [{ "code": 10001, "message": "Server error" }],
  "messages": []
}
```

### Behavior Notes

- The API returns immediately after accepting the URL. Transcoding is asynchronous — the `result.status.state` will be `downloading` initially.
- The source URL must be accessible via HTTPS and must support HTTP HEAD and byte-range GET requests. Azure Blob Storage SAS URLs satisfy both requirements.
- Cloudflare downloads the video from the source URL — the video bytes do not flow through our Function App.
- The `uid` in the response is the primary identifier for all future operations on this video (status checks, playback, deletion).
- Cloudflare supports a maximum file size of 30 GB. Our platform enforces a 50 MB limit (per Feature 002), so this constraint is always satisfied.
- Playback URLs (`hls`, `dash`) are returned immediately but will not serve video content until `readyToStream` becomes `true`.
- If the source URL is unreachable or the download fails, the video state transitions to `error` with `errorReasonCode: ERR_FETCH_ORIGIN_ERROR`.

### Processing State Transitions

```
downloading ──→ queued ──→ inprogress ──→ ready
     │              │            │
     └──→ error     └──→ error   └──→ error
```

| State | `readyToStream` | Description |
|-------|-----------------|-------------|
| `downloading` | `false` | Cloudflare is downloading the video from the source URL |
| `queued` | `false` | Download complete; video is queued for encoding |
| `inprogress` | `false` | Encoding in progress; `pctComplete` updates periodically |
| `ready` | `true` | Video is ready for playback via HLS/DASH |
| `error` | `false` | Processing failed; check `errorReasonCode` for details |

### Rate Limits & Constraints

| Constraint | Value | Impact |
|-----------|-------|--------|
| Concurrent encoding | 120 videos per account (queued + encoding) | Submissions beyond this return HTTP 429 |
| API rate limit | ~1200 requests per 5 minutes | General Cloudflare API limit |
| Max file size | 30 GB | Our 50 MB platform limit is well within |
| Supported formats | MP4, MOV, MKV, AVI, WebM, and others | Our platform supports `video/mp4` and `video/quicktime` |

### Authentication

- The API token is stored in Azure Key Vault as a secret.
- The ProcessVideo function retrieves the token via Key Vault reference in the Function App's application settings.
- The token requires the "Stream Write" permission scope.
- The Cloudflare Account ID is also stored in Key Vault as a secret to avoid exposure in configuration.
