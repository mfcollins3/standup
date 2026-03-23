# API Contract: Standup API

**Base URL**: `https://{apim-instance}.azure-api.net/standup`
**Authentication**: API key via `X-Api-Key` header
**Version**: 1.0 (unversioned path for now; API versioning deferred to future story)

---

## POST /video

Generate a short-lived SAS URL for uploading a video directly to Azure Blob Storage.

### Request

**Headers**:

| Header | Required | Description |
|--------|----------|-------------|
| `X-Api-Key` | Yes | APIM subscription key |
| `Content-Type` | Yes | `application/json` |

**Body** (`application/json`):

```json
{
  "contentType": "video/mp4",
  "fileSizeBytes": 12345678
}
```

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `contentType` | `string` | Yes | Must be `video/mp4` or `video/quicktime` | MIME type of the video |
| `fileSizeBytes` | `integer` | Yes | > 0, <= 52428800 (50 MB) | File size in bytes |

### Response

**200 OK** (`application/json`):

```json
{
  "uploadUrl": "https://ststandup.blob.core.windows.net/status-videos/uploads/user123/550e8400-e29b-41d4-a716-446655440000.mp4?sv=2024-11-04&st=2026-03-22T10:00:00Z&se=2026-03-22T10:15:00Z&sr=b&sp=cw&sig=...",
  "expiresAt": "2026-03-22T10:15:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `uploadUrl` | `string` | Full Blob Storage URL with SAS token appended |
| `expiresAt` | `string` (ISO 8601 UTC) | SAS URL expiry timestamp |

### Error Responses

**400 Bad Request** — Invalid or missing request fields:

```json
{
  "error": {
    "code": "InvalidRequest",
    "message": "fileSizeBytes exceeds maximum allowed size of 52428800 bytes."
  }
}
```

**401 Unauthorized** — Missing or invalid API key:

```json
{
  "error": {
    "code": "Unauthorized",
    "message": "Access denied due to missing subscription key."
  }
}
```

**415 Unsupported Media Type** — Unsupported content type:

```json
{
  "error": {
    "code": "UnsupportedMediaType",
    "message": "contentType must be video/mp4 or video/quicktime."
  }
}
```

**500 Internal Server Error** — Server-side failure (e.g., SAS generation failed):

```json
{
  "error": {
    "code": "InternalError",
    "message": "An unexpected error occurred. Please try again."
  }
}
```

### Behavior Notes

- The SAS URL is scoped to a single blob path, grants **write + create** permissions, and expires in **~15 minutes** (per FR-020).
- The blob path is deterministic: `uploads/{userId}/{server-generated-uuid}.mp4`. The server generates the UUID to prevent client-side collisions.
- The SAS URL uses **user delegation SAS** signed with the Function App's managed identity — no storage account keys involved.
- If a SAS URL expires before the client completes the upload, the client should request a new SAS URL and restart the upload.
- APIM validates the `X-Api-Key` header before the request reaches the Azure Function. Invalid or missing keys are rejected at the gateway.

---

## Upload Flow (Client → Blob Storage)

After obtaining the SAS URL, the iOS client uploads directly to Azure Blob Storage. This is **not** an API Management endpoint — it's a direct PUT to Blob Storage.

### PUT {uploadUrl}

Upload the video file directly to Azure Blob Storage using the SAS URL.

**Headers**:

| Header | Required | Description |
|--------|----------|-------------|
| `x-ms-blob-type` | Yes | `BlockBlob` |
| `Content-Type` | Yes | MIME type matching the `contentType` from the SAS request |
| `Content-Length` | Yes | File size in bytes |

**Body**: Raw video file bytes.

**Response**:
- **201 Created** — Upload successful.
- **403 Forbidden** — SAS URL expired or invalid.
- **413 Request Entity Too Large** — File exceeds size limit.

### iOS Client Example

```swift
var request = URLRequest(url: sasURL)
request.httpMethod = "PUT"
request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")

let task = backgroundSession.uploadTask(with: request, fromFile: videoFileURL)
task.resume()
```

---

## Event Contract: Blob Upload Completed

When a blob is created in the `status-videos` container, Azure Blob Storage emits an Event Grid event. This is **not an API endpoint** — it's an Azure platform event.

**Event Type**: `Microsoft.Storage.BlobCreated`
**Subject filter**: `/blobServices/default/containers/status-videos/blobs/uploads/`

This event triggers downstream processing (transcoding, caption generation, transcript generation). The processing Function(s) are out of scope for this feature but the Event Grid subscription and blob trigger wiring are in scope for the Bicep templates.
