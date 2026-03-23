# Data Model: Upload Status Video for Processing

**Date**: 2026-03-22
**Phase**: 1 — Design & Contracts

---

## Entities

### UploadTask (iOS Client)

Represents a single video upload from the device to Azure Blob Storage.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Unique identifier for this upload task |
| `videoFileURL` | `URL` | Local file URL of the approved recorded video |
| `status` | `UploadStatus` | Current state of the upload |
| `progress` | `Double` | Upload progress (0.0–1.0) |
| `sasURL` | `URL?` | SAS URL issued by the backend for direct blob upload |
| `sasExpiresAt` | `Date?` | Expiry time of the SAS URL |
| `retryCount` | `Int` | Number of automatic retries attempted |
| `errorMessage` | `String?` | Last error message if status is `.failed` |
| `createdAt` | `Date` | When the upload task was created |
| `urlSessionTaskIdentifier` | `Int?` | URLSession task identifier for reconnecting after app restart |

**Validation Rules**:
- `videoFileURL` must point to an existing file on disk.
- `progress` is clamped to 0.0–1.0.
- `retryCount` must be >= 0 and <= max retry limit (3).
- `sasURL` must be non-nil before transitioning to `.uploading`.

### UploadStatus (iOS Client)

Enum representing the state of an upload task.

```
┌─────────┐   SAS URL    ┌───────────┐   upload    ┌───────────┐
│ pending  │──obtained───▶│ uploading │──complete──▶│ completed │
└─────────┘              └───────────┘              └───────────┘
     │                       │    │
     │ cancel                │    │ transient error
     ▼                       │    ▼
┌───────────┐                │  ┌──────────┐  retries   ┌────────┐
│ cancelled │◀──cancel───────┘  │ retrying │──exceed──▶│ failed │
└───────────┘       ▲           └──────────┘            └────────┘
                    │                │   │                  │
                    │ cancel         │   │ success          │ manual retry
                    └────────────────┘   ▼                  ▼
                                    ┌───────────┐     ┌─────────┐
                                    │ uploading │     │ pending │
                                    └───────────┘     └─────────┘
```

| Value | Description |
|-------|-------------|
| `pending` | Upload created, awaiting SAS URL or network connectivity |
| `uploading` | Actively transferring data to Blob Storage |
| `retrying` | Automatic retry in progress after a transient failure |
| `completed` | Upload finished successfully, server acknowledged receipt |
| `failed` | All automatic retries exhausted; user must manually retry or discard |
| `cancelled` | User cancelled the upload |

**Transitions**:
- `pending` → `uploading`: SAS URL obtained and upload task started
- `pending` → `cancelled`: User cancels before upload begins
- `uploading` → `completed`: Upload finishes successfully
- `uploading` → `retrying`: Transient error (network timeout, 5xx)
- `uploading` → `cancelled`: User cancels during upload
- `retrying` → `uploading`: Retry attempt starts
- `retrying` → `failed`: Max retries exceeded
- `retrying` → `cancelled`: User cancels during retry wait
- `failed` → `pending`: User taps manual retry

### SasUrlResponse (iOS Client / API Contract)

Response from the backend API when requesting a SAS URL.

| Field | Type | Description |
|-------|------|-------------|
| `uploadUrl` | `String` | Full SAS URL for direct blob upload (includes SAS token) |
| `expiresAt` | `String` (ISO 8601) | When the SAS URL expires |

### SasUrlRequest (API Contract)

Request body sent to the backend to obtain a SAS URL.

| Field | Type | Description |
|-------|------|-------------|
| `contentType` | `String` | MIME type of the video (e.g., `video/mp4`) |
| `fileSizeBytes` | `Int64` | Size of the video file in bytes |

**Validation Rules**:
- `contentType` must be a supported video MIME type (`video/mp4`, `video/quicktime`).
- `fileSizeBytes` must be > 0 and <= 52,428,800 (50 MB).

### CellularUploadPreference (iOS Client)

User preference for cellular upload behavior.

| Field | Type | Description |
|-------|------|-------------|
| `isSet` | `Bool` | Whether the user has made a choice |
| `allowsCellular` | `Bool` | Whether cellular uploads are permitted |

Stored in `UserDefaults`. Checked before starting any upload on a cellular connection.

---

## Relationships

```
RecordedVideo (Feature 001)
      │
      │ 1:1
      ▼
  UploadTask ──── SasUrlResponse (from backend API)
      │
      │ on completion (Blob Storage event)
      ▼
  ProcessingJob (future feature — triggered by Event Grid)
      │
      ├── 1:1 ── Transcript
      └── 1:1 ── Caption
```

- A **RecordedVideo** (from Feature 001) maps to exactly one **UploadTask**.
- An **UploadTask** requests one **SasUrlResponse** from the backend. If the SAS URL expires before upload completes, a new SAS URL is requested.
- Once the blob upload completes, Azure Blob Storage fires an Event Grid event that triggers a **ProcessingJob** (out of scope for this feature's implementation, but the blob event trigger is in scope).
- A **ProcessingJob** produces one **Transcript** and one **Caption** (both out of scope for detailed implementation).

---

## Storage

### Azure Blob Storage

- **Container**: `status-videos`
- **Blob naming**: `uploads/{userId}/{uuid}.mp4`
  - `userId` — authenticated user's identifier (placeholder until auth feature)
  - `uuid` — server-generated UUID (created by the Azure Function at SAS URL generation time)
- **Access tier**: Hot (videos are accessed soon after upload for processing)
- **Redundancy**: LRS (locally redundant — sufficient for a single-region startup)

### iOS Local Storage

- Recorded video file persists at the URL provided by Feature 001 until upload is confirmed or user discards it.
- `UploadTask` state is managed in memory by `UploadService` and reconstructed from `URLSession` background session on app relaunch.
- `CellularUploadPreference` stored in `UserDefaults`.
