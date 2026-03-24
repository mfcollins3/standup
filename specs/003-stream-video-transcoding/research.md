# Research: Stream Video Transcoding via Cloudflare Stream

**Date**: 2026-03-23

---

## R-001: Event Grid Trigger SDK for .NET Isolated Worker

**Decision**: Use `Microsoft.Azure.Functions.Worker.Extensions.EventGrid` version 3.6.0.

**Rationale**: This is the correct package for Event Grid triggers in the .NET isolated worker model (not the in-process WebJobs package). Version 3.6.0 supports SDK type bindings with `Azure.Messaging.EventGrid.EventGridEvent` and `Azure.Messaging.EventGrid.SystemEvents.StorageBlobCreatedEventData` for strongly-typed event deserialization.

**Key Findings**:

- Package: `Microsoft.Azure.Functions.Worker.Extensions.EventGrid` 3.6.0
- Do NOT use `Microsoft.Azure.WebJobs.Extensions.EventGrid` (in-process model only)
- Function signature uses `[EventGridTrigger] EventGridEvent` parameter type
- `StorageBlobCreatedEventData` available via `eventGridEvent.Data.ToObjectFromJson<StorageBlobCreatedEventData>()`
- Supports constructor DI natively in isolated worker model
- Subscription validation handshake is handled automatically by the Functions runtime at `/runtime/webhooks/eventgrid`

**Trigger Binding Syntax**:

```csharp
using Azure.Messaging.EventGrid;
using Azure.Messaging.EventGrid.SystemEvents;
using Microsoft.Azure.Functions.Worker;

[Function(nameof(ProcessVideo))]
public async Task Run([EventGridTrigger] EventGridEvent eventGridEvent)
{
    var blobData = eventGridEvent.Data.ToObjectFromJson<StorageBlobCreatedEventData>();
    // blobData.Url, blobData.ContentType, blobData.ContentLength, blobData.Api
}
```

**BlobCreated Event Schema** (key data fields):

| Field | Type | Description |
|-------|------|-------------|
| `Url` | `string` | Full blob URL |
| `Api` | `string` | REST API that created the blob (`PutBlob`, `PutBlockList`, `CopyBlob`) |
| `ContentType` | `string` | MIME type |
| `ContentLength` | `long` | Size in bytes |
| `BlobType` | `string` | `BlockBlob`, `PageBlob`, etc. |
| `ETag` | `string` | Useful for idempotency |

**Local Testing**: POST to `http://localhost:7071/runtime/webhooks/EventGrid?functionName=ProcessVideo` with `aeg-event-type: Notification` header and an Event Grid event array in the body.

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| In-process model (`WebJobs.Extensions.EventGrid`) | Project uses isolated worker; incompatible |
| CloudEvent schema | Event Grid system topic for Storage uses Event Grid schema by default; CloudEvent would require schema conversion |
| Blob trigger instead of Event Grid | Higher latency (polling-based), less reliable for high-throughput, no filtering by path prefix |

---

## R-002: Cloudflare Stream "Upload from URL" API

**Decision**: Use the Cloudflare Stream `POST /stream/copy` endpoint with Bearer token authentication.

**Rationale**: This is the purpose-built Cloudflare API for submitting external URLs for transcoding. Azure Blob Storage SAS URLs are fully compatible (support HEAD and GET range requests). The API returns a video UID immediately that can be stored for future status checks and playback integration.

**Key Findings**:

- **Endpoint**: `POST https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/copy`
- **Auth**: `Authorization: Bearer <API_TOKEN>` (API Token with "Stream Write" permission)
- **Required field**: `url` — the source URL (our read SAS URL)
- **Optional fields**: `meta` (key-value metadata), `allowedOrigins`, `requireSignedURLs`, `thumbnailTimestampPct`, `scheduledDeletion`
- **Response**: Cloudflare v4 envelope with `result.uid`, `result.status.state`, `result.playback.hls`, `result.playback.dash`

**Rate Limits**:

| Limit | Value |
|-------|-------|
| Concurrent encoding | 120 videos per account (queued + encoding) |
| API rate limit | ~1200 requests per 5 minutes (general Cloudflare API limit) |
| Exceeding limits | HTTP 429 response |

**Size Limits**:

| Constraint | Value |
|-----------|-------|
| Max file size | 30 GB (our limit is 50 MB — well within) |
| Supported formats | MP4, MOV, MKV, AVI, WebM, and others |

**Processing States**:

| State | `readyToStream` | Description |
|-------|-----------------|-------------|
| `downloading` | `false` | Cloudflare downloading from source URL |
| `queued` | `false` | Download complete, awaiting encoding |
| `inprogress` | `false` | Encoding in progress (`pctComplete` updates) |
| `ready` | `true` | Playable via HLS/DASH |
| `error` | `false` | Failed — check `errorReasonCode` |

**Processing Error Codes**:

| Code | Description |
|------|-------------|
| `ERR_NON_VIDEO` | File is not a recognized video format |
| `ERR_FETCH_ORIGIN_ERROR` | Could not download from source URL (403, 404, timeout) |
| `ERR_MALFORMED_VIDEO` | Corrupt or undecodable video |
| `ERR_DURATION_EXCEED_CONSTRAINT` | Duration exceeds constraint |
| `ERR_DURATION_TOO_SHORT` | Video too short |

**Error Response Format**:

```json
{
  "result": null,
  "success": false,
  "errors": [{ "code": 10005, "message": "Description" }],
  "messages": []
}
```

**Webhook Support**: Cloudflare supports webhooks for transcoding completion notifications. Registration via `PUT /stream/webhook` with a `notificationUrl`. Returns a `secret` for HMAC signature verification. This is out of scope for this feature but relevant for future status tracking.

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| Direct upload (TUS protocol) | Requires streaming the video through our Function — unnecessary double-transfer of data |
| Cloudflare R2 + Stream integration | Adds R2 dependency; SAS URL approach is simpler and uses existing Blob Storage |
| Self-hosted transcoding (FFmpeg) | Constitution Principle VII (Simplicity) — Cloudflare handles transcoding, CDN delivery, and adaptive bitrate |

---

## R-003: Event Grid Subscription Deployment Ordering

**Decision**: Extract Event Grid resources into a separate `event-grid.bicep` module that depends on both `storage` and `functionApp` modules. Use a conditional `enableEventGrid` parameter for first-time deployments.

**Rationale**: The Event Grid event subscription performs a synchronous webhook validation handshake when created. The target Function App must be deployed, running, and have the `eventgrid_extension` system key available. This creates a dependency ordering challenge that is best solved by separating Event Grid into its own module.

**Key Findings**:

- **Problem**: Event Grid subscription creation sends a validation request to the webhook URL. If the Function App doesn't exist or the function code isn't deployed, the handshake fails and the Bicep deployment errors out.
- **System key**: The `eventgrid_extension` system key is created by the Functions runtime when it loads the Event Grid extension, NOT when the Function App resource is provisioned. On first deploy, the key won't exist until the code is deployed and the app starts.
- **listKeys syntax**: `listKeys('${functionAppId}/host/default', '2024-04-01').systemKeys.eventgrid_extension`
- **Webhook URL format**: `https://{hostName}/runtime/webhooks/eventgrid?functionName=ProcessVideo&code={systemKey}`

**Deployment Module Structure**:

```
monitoring → (no deps)
storage → (no deps)
functionApp → storage, monitoring
eventGrid → storage, functionApp      ← NEW MODULE
keyVault → functionApp
apim → functionApp
```

**First-Time Bootstrap Strategy**:

1. First deployment: `enableEventGrid = false` — deploys everything except Event Grid subscription
2. Code deployment: `azd deploy` pushes function code, runtime starts, system key is created
3. Second deployment: `enableEventGrid = true` — Event Grid subscription is created with valid webhook URL

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| Event Grid resources inside `storage.bicep` | Creates circular dependency (storage ← functionApp but Event Grid needs functionApp) |
| Pass functionApp outputs into storage module | Messier dependency graph; conflates storage and eventing concerns |
| Azure CLI post-deployment script | Violates Constitution Principle V (Infrastructure as Code) — all resources must be in Bicep |
| Blob trigger instead of Event Grid | Higher latency, no path filtering, less reliable at scale |

---

## R-004: Read SAS URL Generation for Cloudflare

**Decision**: Extend the existing `ISasUrlService` with a `GenerateReadSasUrlAsync` method. Use 1-hour expiry, read-only permission, single-blob scope, HTTPS-only.

**Rationale**: The existing `SasUrlService` already implements user delegation key–based SAS generation with the correct security patterns (managed identity, no shared keys). Adding a read method follows the same pattern with different permissions and longer expiry.

**Key Findings**:

- Existing service generates **write+create** SAS with 15-minute expiry
- Read SAS needs: `BlobSasPermissions.Read`, ~60-minute expiry (per FR-003 in spec)
- Cloudflare requires: HTTP HEAD and GET range requests — both work with read-only SAS
- User delegation key validity: max 7 days; current code uses expiry-aligned keys
- No code changes needed to `BlobServiceClient` registration — same client works for read SAS

**Design Approach**:

```csharp
// New method on ISasUrlService
Task<SasUrlResult> GenerateReadSasUrlAsync(string blobPath, CancellationToken cancellationToken = default);
```

The implementation mirrors `GenerateSasUrlAsync` but uses `BlobSasPermissions.Read` and a 60-minute expiry window.

**Alternatives Considered**:

| Alternative | Rejected Because |
|------------|-----------------|
| New service class for read SAS | Duplicates user delegation key logic; existing service already has the BlobServiceClient and pattern |
| Account-level SAS | Overly broad permissions; violates least-privilege (Constitution Principle IV) |
| Shared access key SAS | Storage account has shared key access disabled; only user delegation SAS is possible |
| Pass blob URL directly without SAS | Container has no public access; Cloudflare can't download without auth |
