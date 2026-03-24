# Contract Changes: CreateVideo Endpoint

**Feature**: 005 — Video Tracking and Persistence
**Direction**: Inbound — iPhone client → CreateVideo function
**Change Type**: Modified response body (backward-incompatible: new required field)

---

## Endpoint (Unchanged)

| Property | Value |
|----------|-------|
| Method | `POST` |
| Route | `/api/video` |
| Authorization Level | `Anonymous` |
| Function Name | `CreateVideo` |

---

## Request (Unchanged)

```json
{
  "contentType": "video/mp4",
  "fileSizeBytes": 12345678
}
```

---

## Response — Changed

### Before (Feature 002)

```json
{
  "uploadUrl": "https://storageaccount.blob.core.windows.net/uploads/anonymous/...",
  "expiresAt": "2026-03-24T15:00:00Z"
}
```

### After (Feature 005)

```json
{
  "videoId": "550e8400-e29b-41d4-a716-446655440000",
  "uploadUrl": "https://storageaccount.blob.core.windows.net/uploads/anonymous/...",
  "expiresAt": "2026-03-24T15:00:00Z"
}
```

| Field | Type | New? | Description |
|-------|------|------|-------------|
| `videoId` | `string` (GUID) | **Yes** | Identifier of the newly created Video record in the database |
| `uploadUrl` | `string` | No | SAS URL for uploading the video to Azure Blob Storage |
| `expiresAt` | `string` (ISO 8601) | No | Expiration time of the SAS URL |

**Impact**: The iOS client will need to be updated to read `videoId` from the response. Existing clients that ignore unknown fields are unaffected by the addition. However, any client validation that strictly checks the response schema will need updating.

---

## Side Effects — New

When CreateVideo successfully creates a video record:

| Action | Description |
|--------|-------------|
| Database INSERT | A new row is inserted into the `Videos` table with status `created`, the placeholder user ID, blob path, content type, and file size |

---

## Error Responses (Unchanged)

| Scenario | Status Code | Body |
|----------|-------------|------|
| Invalid content type | `400 Bad Request` | `{ "error": { "code": "invalid_content_type", ... } }` |
| File size exceeds limit | `400 Bad Request` | `{ "error": { "code": "file_too_large", ... } }` |
| Missing required fields | `400 Bad Request` | `{ "error": { "code": "bad_request", ... } }` |
