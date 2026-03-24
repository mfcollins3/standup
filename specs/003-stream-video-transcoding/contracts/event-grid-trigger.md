# Event Contract: Blob Storage → Event Grid → ProcessVideo

**Direction**: Inbound — Azure Event Grid delivers events to the ProcessVideo function
**Event Source**: Azure Blob Storage system topic
**Event Schema**: Event Grid schema (not CloudEvents)

---

## Event Grid System Topic

| Property | Value |
|----------|-------|
| Topic type | `Microsoft.Storage.StorageAccounts` |
| Source resource | Storage account (`ststandup{token}`) |
| Schema | Event Grid schema |

---

## Event Subscription: ProcessVideo

| Property | Value |
|----------|-------|
| Event types | `Microsoft.Storage.BlobCreated` |
| Subject filter (begins with) | `/blobServices/default/containers/status-videos/blobs/uploads/` |
| Endpoint type | Webhook |
| Endpoint URL | `https://{functionApp}.azurewebsites.net/runtime/webhooks/eventgrid?functionName=ProcessVideo&code={systemKey}` |
| Max delivery attempts | 30 |
| Event time-to-live | 1440 minutes (24 hours) |
| Dead-letter destination | `status-videos` container, `deadletter/` path |

### Webhook Endpoint Notes

- The endpoint URL uses the Functions runtime's built-in Event Grid webhook handler at `/runtime/webhooks/eventgrid`.
- The `functionName` query parameter routes the event to the `ProcessVideo` function.
- The `code` query parameter is the `eventgrid_extension` system key, automatically created by the Functions runtime when it loads the Event Grid extension.
- The Functions runtime handles the Event Grid subscription validation handshake automatically.
- The system key is retrieved in Bicep via: `listKeys('${functionAppId}/host/default', '2024-04-01').systemKeys.eventgrid_extension`.

---

## BlobCreated Event

**Event Type**: `Microsoft.Storage.BlobCreated`

### Envelope

```json
[
  {
    "id": "b0c0e7f0-4f6d-4b7a-8c9d-1e2f3a4b5c6d",
    "topic": "/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{account}",
    "subject": "/blobServices/default/containers/status-videos/blobs/uploads/anonymous/550e8400-e29b-41d4-a716-446655440000.mp4",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2026-03-23T14:30:00.0000000Z",
    "dataVersion": "",
    "metadataVersion": "1",
    "data": {
      "api": "PutBlob",
      "clientRequestId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "requestId": "f0e1d2c3-b4a5-6789-0123-456789abcdef",
      "eTag": "0x8DB12345ABCDEF0",
      "contentType": "video/mp4",
      "contentLength": 12345678,
      "blobType": "BlockBlob",
      "url": "https://ststandup.blob.core.windows.net/status-videos/uploads/anonymous/550e8400-e29b-41d4-a716-446655440000.mp4",
      "sequencer": "00000000000000000000000000000123400000000000abcdef",
      "storageDiagnostics": {
        "batchId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
      }
    }
  }
]
```

### Event Data Fields (`StorageBlobCreatedEventData`)

| Field | Type | Description | Used By ProcessVideo |
|-------|------|-------------|---------------------|
| `api` | `string` | REST API that created the blob (`PutBlob`, `PutBlockList`, `CopyBlob`) | No |
| `clientRequestId` | `string` | Client-provided request ID | No |
| `requestId` | `string` | Service-generated request ID | No |
| `eTag` | `string` | Entity tag — useful for idempotency checks (FR-008) | Yes |
| `contentType` | `string` | MIME type of the uploaded blob | Yes — validated against supported formats (FR-010) |
| `contentLength` | `long` | Size of the blob in bytes | Yes — validated against size limits |
| `blobType` | `string` | `BlockBlob`, `PageBlob`, or `AppendBlob` | No |
| `url` | `string` | Full URL of the created blob (without SAS token) | Yes — used to extract blob path for SAS URL generation |
| `sequencer` | `string` | Opaque value for ordering events | No |

### Trigger Binding

The ProcessVideo function receives the event as an `EventGridEvent` object via the Event Grid trigger binding:

```csharp
[Function(nameof(ProcessVideo))]
public async Task Run([EventGridTrigger] EventGridEvent eventGridEvent)
{
    var blobData = eventGridEvent.Data.ToObjectFromJson<StorageBlobCreatedEventData>();
    // Validate: blobData.ContentType, blobData.ContentLength
    // Extract blob path from blobData.Url
    // Generate read SAS URL via ISasUrlService
    // Submit to Cloudflare Stream via ICloudflareStreamService
}
```

### Validation Rules (ProcessVideo)

| Check | Condition | Action on Failure |
|-------|-----------|-------------------|
| Supported content type (FR-010) | `contentType` is `video/mp4` or `video/quicktime` | Log warning, acknowledge event, skip processing |
| Within size limits | `contentLength` <= 52,428,800 (50 MB) | Log warning, acknowledge event, skip processing |
| Idempotency (FR-008) | Event `eTag` has not been processed before | Log info, acknowledge event, skip duplicate |

### Retry & Dead-Letter Policy

| Property | Value | Rationale |
|----------|-------|-----------|
| Max delivery attempts | 30 | Allows extended recovery from transient failures |
| Event time-to-live | 1440 minutes (24 hours) | Events expire after 24 hours if undeliverable |
| Dead-letter container | `status-videos` | Same storage account for operational simplicity |
| Dead-letter path | `deadletter/` | Isolates failed events from video uploads |

Dead-lettered events should trigger an operational alert when the dead-letter blob count exceeds a threshold (per edge case: extended transcoding service outage).

---

## Local Development

For local testing, events are delivered via HTTP POST to the Functions runtime:

**Endpoint**: `POST http://localhost:7071/runtime/webhooks/EventGrid?functionName=ProcessVideo`

**Headers**:

| Header | Value |
|--------|-------|
| `aeg-event-type` | `Notification` |
| `Content-Type` | `application/json` |

**Body**: Event Grid event array (same JSON format as the envelope above).
