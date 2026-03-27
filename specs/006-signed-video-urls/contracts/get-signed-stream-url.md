# API Contract: Get Signed Stream URL

**Endpoint**: `GET /video/{videoId}/stream?streamType={streamType}`
**APIM Path**: `GET /standup/video/{videoId}/stream?streamType={streamType}`

## Request

### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `videoId` | `string` (GUID) | Yes | The internal video identifier. |

### Query Parameters

| Parameter | Type | Required | Allowed Values | Description |
|-----------|------|----------|----------------|-------------|
| `streamType` | `string` | Yes | `hls`, `dash` | The streaming format. Case-insensitive. |

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Api-Key` | Yes | APIM subscription key (enforced at the APIM gateway level). |

## Responses

### 200 OK — Signed URL generated successfully

```json
{
  "signedUrl": "https://customer-<CODE>.cloudflarestream.com/<TOKEN>/manifest/video.m3u8",
  "expiresAt": "2026-03-26T14:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `signedUrl` | `string` | The time-limited signed manifest URL for the requested stream type. |
| `expiresAt` | `string` (ISO 8601) | When the signed URL expires. |

### 400 Bad Request — Invalid or missing stream type

```json
{
  "error": {
    "code": "invalid_stream_type",
    "message": "The streamType query parameter must be 'hls' or 'dash'."
  }
}
```

### 404 Not Found — Video does not exist

```json
{
  "error": {
    "code": "video_not_found",
    "message": "No video was found with the specified ID."
  }
}
```

### 409 Conflict — Video not ready for streaming

```json
{
  "error": {
    "code": "video_not_ready",
    "message": "The video is not yet ready for streaming. Current status: processing."
  }
}
```

## Notes

- The signed URL replaces the video UID in the standard Cloudflare manifest URL with an RS256 JWT token.
- Tokens expire after 1 hour by default.
- The iOS client should request a fresh signed URL if playback fails due to token expiration.
- Both `hls` and `dash` values are accepted case-insensitively.
