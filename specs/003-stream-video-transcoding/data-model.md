# Data Model: Stream Video Transcoding via Cloudflare Stream

**Date**: 2026-03-23
**Phase**: 1 — Design & Contracts

---

## Entities

### StorageBlobCreatedEventData (Azure SDK — consumed, not defined)

The incoming event payload from Event Grid when a blob is created in the `status-videos` container. Deserialized from the `EventGridEvent.Data` property.

| Field | Type | Description |
|-------|------|-------------|
| `Url` | `string` | Full URL of the created blob |
| `Api` | `string` | REST API that created the blob (`PutBlob`, `PutBlockList`, `CopyBlob`) |
| `ContentType` | `string` | MIME type of the blob |
| `ContentLength` | `long` | Size of the blob in bytes |
| `BlobType` | `string` | `BlockBlob`, `PageBlob`, etc. |
| `ETag` | `string` | Entity tag; useful for idempotency checks |

**Source**: `Azure.Messaging.EventGrid.SystemEvents.StorageBlobCreatedEventData`

**Validation Rules (applied by ProcessVideo function)**:
- `ContentType` must be one of `video/mp4`, `video/quicktime`.
- `ContentLength` must be > 0 and <= 52,428,800 (50 MB).
- Blob path (parsed from `Url`) must start with `uploads/`.

---

### CloudflareStreamRequest (New — `api/Models/`)

Request body sent to the Cloudflare Stream "Upload from URL" endpoint.

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Url` | `string` | `url` | Read SAS URL for the uploaded video blob |
| `Meta` | `Dictionary<string, string>?` | `meta` | Optional metadata (e.g., blob path for traceability) |
| `RequireSignedURLs` | `bool?` | `requireSignedURLs` | Whether playback URLs require signing |

**Validation Rules**:
- `Url` must be a valid HTTPS URI.
- `Url` must contain a SAS token (query string includes `sig=`).

---

### CloudflareStreamResponse (New — `api/Models/`)

Response from the Cloudflare Stream "Upload from URL" endpoint. Follows the Cloudflare v4 API envelope pattern.

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Success` | `bool` | `success` | Whether the API call succeeded |
| `Result` | `CloudflareStreamResult?` | `result` | Video details on success; `null` on error |
| `Errors` | `List<CloudflareError>` | `errors` | Error details when `Success` is `false` |
| `Messages` | `List<CloudflareMessage>` | `messages` | Informational messages |

### CloudflareStreamResult (New — `api/Models/`)

The `result` object within the Cloudflare Stream response.

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Uid` | `string` | `uid` | Cloudflare Stream video identifier |
| `ReadyToStream` | `bool` | `readyToStream` | Whether the video is playable |
| `Status` | `CloudflareStatus` | `status` | Current processing status |
| `Playback` | `CloudflarePlayback?` | `playback` | Playback URLs (available when ready) |

### CloudflareStatus (New — `api/Models/`)

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `State` | `string` | `state` | Processing state: `downloading`, `queued`, `inprogress`, `ready`, `error` |
| `PctComplete` | `string?` | `pctComplete` | Percentage complete during encoding |
| `ErrorReasonCode` | `string?` | `errorReasonCode` | Error code if `State` is `error` |
| `ErrorReasonText` | `string?` | `errorReasonText` | Human-readable error description |

### CloudflarePlayback (New — `api/Models/`)

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Hls` | `string?` | `hls` | HLS manifest URL |
| `Dash` | `string?` | `dash` | DASH manifest URL |

### CloudflareError (New — `api/Models/`)

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Code` | `int` | `code` | Numeric error code |
| `Message` | `string` | `message` | Error description |

### CloudflareMessage (New — `api/Models/`)

| Field | Type | JSON Property | Description |
|-------|------|---------------|-------------|
| `Code` | `int` | `code` | Numeric message code |
| `Message` | `string` | `message` | Informational text |

---

### SasUrlResult (Existing — `api/Services/ISasUrlService.cs`)

Already defined. Used for both write SAS (existing) and read SAS (new method).

| Field | Type | Description |
|-------|------|-------------|
| `SasUri` | `Uri` | Full blob URL with SAS token appended |
| `ExpiresAt` | `DateTimeOffset` | When the SAS URL expires |

**Extended Usage**: The new `GenerateReadSasUrlAsync` method returns the same `SasUrlResult` record, with `BlobSasPermissions.Read` and a 60-minute expiry window.

---

## State Transitions

### Cloudflare Stream Video Processing States

```
┌──────────────┐  download    ┌────────┐  encoding    ┌─────────────┐  complete    ┌────────┐
│ downloading  │─────done────▶│ queued │─────start───▶│ inprogress  │────done─────▶│ ready  │
└──────────────┘              └────────┘              └─────────────┘              └────────┘
       │                           │                        │
       │ fetch error               │ encoding error         │ encoding error
       ▼                           ▼                        ▼
   ┌────────┐                  ┌────────┐               ┌────────┐
   │ error  │                  │ error  │               │ error  │
   └────────┘                  └────────┘               └────────┘
```

| State | `readyToStream` | Description |
|-------|-----------------|-------------|
| `downloading` | `false` | Cloudflare is downloading the video from our SAS URL |
| `queued` | `false` | Download complete, awaiting encoding slot |
| `inprogress` | `false` | Encoding in progress; `pctComplete` updates periodically |
| `ready` | `true` | Video is playable via HLS/DASH |
| `error` | `false` | Processing failed — check `errorReasonCode` |

**Error Codes**:

| Code | Description | Our Response |
|------|-------------|--------------|
| `ERR_NON_VIDEO` | File is not a recognized video format | Log as permanent failure |
| `ERR_FETCH_ORIGIN_ERROR` | Could not download from SAS URL (expired, 403, 404) | Log as permanent failure |
| `ERR_MALFORMED_VIDEO` | Corrupt or undecodable video | Log as permanent failure |
| `ERR_DURATION_EXCEED_CONSTRAINT` | Duration exceeds account constraint | Log as permanent failure |
| `ERR_DURATION_TOO_SHORT` | Video too short | Log as permanent failure |

---

### ProcessVideo Function Event Flow

```
    Event Grid delivers BlobCreated event
                    │
                    ▼
    ┌───────────────────────────────┐
    │  Validate event (content type, │
    │  size, path prefix)           │
    └───────────────┬───────────────┘
                    │
            valid   │   invalid
         ┌──────────┴──────────┐
         ▼                     ▼
    Generate read         Log skip,
    SAS URL               acknowledge event
         │
         ▼
    Submit SAS URL
    to Cloudflare Stream
         │
    ┌────┴────┐
    │ success │  failure
    ▼         ▼
  Log UID   Throw exception
  + store   (runtime retries
  result     via Event Grid
              retry policy)
```

---

## Relationships

```
Feature 002: CreateVideo (POST /video)
       │
       │ uploads blob to status-videos/uploads/{userId}/{uuid}.{ext}
       ▼
Azure Blob Storage ── Event Grid ──▶ ProcessVideo Function
       │                                     │
       │ blob read via SAS URL               │ submit SAS URL
       │◀────────────────────────────────────┘
       │
       │ Cloudflare downloads via SAS URL
       ▼
Cloudflare Stream ── transcodes ──▶ HLS/DASH playback URLs
```

- A **blob upload** (from Feature 002) triggers exactly one **BlobCreated event**.
- Event Grid may deliver the event more than once; the function handles duplicates idempotently.
- The **ProcessVideo function** generates one **read SAS URL** per event and submits it to **Cloudflare Stream**.
- Cloudflare Stream returns a **video UID** that uniquely identifies the transcoding job and is associated with the original blob path for status tracking.
- One uploaded blob maps to exactly one Cloudflare Stream video UID.

---

## Storage

### Azure Blob Storage

- **Container**: `status-videos` (existing)
- **Blob path format**: `uploads/{userId}/{uuid}.{extension}` (created by Feature 002)
- **Event Grid filter**: `/blobServices/default/containers/status-videos/blobs/uploads/`
- **Events**: `Microsoft.Storage.BlobCreated`
- **No new storage containers** are needed for this feature.

### Azure Key Vault

- **`CloudflareStreamApiToken`**: Cloudflare API token with "Stream Write" permission
- **`CloudflareStreamAccountId`**: Cloudflare account identifier

Both secrets are referenced by the Function App via Key Vault references in app settings.

### Application Logging

- **Application Insights**: All processing attempts logged with blob path, content type, content length, Cloudflare video UID (on success), and error details (on failure).
- **Structured logging**: Uses `ILogger<ProcessVideo>` with semantic log properties for queryability.
