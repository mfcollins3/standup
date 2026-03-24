# Contract Changes: ProcessVideo Function

**Feature**: 005 — Video Tracking and Persistence
**Direction**: Internal — Event Grid (BlobCreated) → ProcessVideo function → Cloudflare Stream API
**Change Type**: Database side effects added (no external contract change)

---

## Trigger (Unchanged)

| Property | Value |
|----------|-------|
| Trigger Type | Event Grid |
| Event Type | `Microsoft.Storage.BlobCreated` |
| Subject Filter | Starts with `/blobServices/default/containers/uploads/blobs/` |
| Function Name | `ProcessVideo` |

---

## External Behavior (Modified)

ProcessVideo continues to:

1. Validate the incoming blob event
2. Generate a read-only SAS URL for the blob
3. Submit the video to Cloudflare Stream for transcoding

### Cloudflare Stream Meta Enhancement

The Cloudflare `/stream/copy` API call is updated to include the Video record's `Id` in the `meta` dictionary alongside the existing `blobPath`:

| Meta Key | Value | Purpose |
|----------|-------|---------|
| `blobPath` | Blob name from Event Grid event | Existing — traceability |
| `videoId` | `Video.Id.ToString()` | **New** — enables direct primary key lookup in the CloudflareWebhook handler |

This requires updating `ICloudflareStreamService.SubmitForTranscodingAsync` to accept the video ID (as a `Guid`) in addition to the existing parameters. The service implementation adds the `videoId` entry to the meta dictionary before submitting to Cloudflare.

**Service Signature Change**:
```
Before: SubmitForTranscodingAsync(Uri videoReadUrl, string blobPath, CancellationToken cancellationToken)
After:  SubmitForTranscodingAsync(Uri videoReadUrl, string blobPath, Guid videoId, CancellationToken cancellationToken)
```

---

## Side Effects — New

### On Event Received

| Action | Description |
|--------|-------------|
| Database SELECT | Look up Video record by `blob_path` matching the blob name from the Event Grid event |
| Validation | If no matching Video record is found, log a warning and skip database operations (function still processes the event for backward compatibility) |

### After Cloudflare Submission

| Action | Description |
|--------|-------------|
| Database UPDATE | Set `status` → `processing` |
| Database UPDATE | Set `cloudflare_video_uid` → UID returned from Cloudflare Stream API |
| Database UPDATE | Set `updated_at` → current UTC timestamp |

---

## State Transitions

```text
Video.Status:  created  ──►  uploaded  ──►  processing
                              (future)       (this function)
```

> **Note**: The `uploaded` status transition is reserved for a future blob-upload-confirmed event. In the initial implementation, ProcessVideo transitions directly from `created` to `processing` since the BlobCreated event confirms the upload.

---

## Error Handling

| Scenario | Database Action | Function Behavior |
|----------|----------------|-------------------|
| No Video found for blob path | None (log warning) | Continue processing normally (videoId not included in meta) |
| Cloudflare API failure | Set status → `failed`, store error details | Throw exception (Event Grid retry) |
| Database unavailable | None | Log error, continue with Cloudflare submission (videoId not included in meta) |
