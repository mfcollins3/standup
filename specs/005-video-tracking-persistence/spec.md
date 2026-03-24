# Feature Specification: Video Tracking and Persistence

**Feature Branch**: `005-video-tracking-persistence`
**Created**: 2026-03-24
**Status**: Draft
**Input**: User description: "I want to begin tracking videos that are being uploaded and saving the URLs for the video (thumbnail, watch, HLS, and DASH) received from Cloudflare. I want to track the video's status in the database (e.g. created -> uploaded -> processing -> ready or failed). Since I don't have user identity/authentication implemented as a feature yet, treat all video uploads as coming from the same user using a constant user ID value that we can replace or enhance later to represent other user IDs. Update each of the Azure Functions to update the database with relevant information that they receive or can update at each stage."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Track Video Lifecycle Status (Priority: P1)

When a team member initiates a video upload, the system creates a video record in the database with a "created" status. As the video moves through the pipeline — uploaded to blob storage, submitted for transcoding, and processed by Cloudflare — the system updates the video's status at each stage. This provides a single source of truth for the current state of every video in the system.

**Why this priority**: Without tracking video status, Naked Standup has no way to know what happened to a video after it was uploaded. Status tracking is the foundation for all downstream features: showing upload progress, displaying ready videos, and handling failures.

**Independent Test**: Create a video record via the CreateVideo endpoint, simulate blob upload (triggering ProcessVideo), and send a Cloudflare webhook notification. Verify the video record's status transitions through created → processing → ready. Also verify the failed path when Cloudflare reports an error.

**Acceptance Scenarios**:

1. **Given** a user requests a video upload via POST /api/video, **When** the request is valid, **Then** a new video record is created in the database with status "created", a constant placeholder user ID, the blob path, and the content type.
2. **Given** a video record exists with status "created", **When** a BlobCreated event is received, ProcessVideo matches the blob path, and the video is successfully submitted to Cloudflare Stream, **Then** the video's status is updated to "processing" and the Cloudflare video UID is stored on the record.
4. **Given** a video has status "processing", **When** a Cloudflare webhook notification indicates the video is ready to stream, **Then** the video's status is updated to "ready" and the playback URLs (HLS, DASH), thumbnail URL, duration, and input dimensions are stored.
5. **Given** a video has status "processing", **When** a Cloudflare webhook notification indicates processing failed, **Then** the video's status is updated to "failed" and the error details are stored.

---

### User Story 2 - Store Cloudflare Playback URLs (Priority: P1)

When Cloudflare finishes transcoding a video, the webhook notification includes playback URLs (HLS and DASH streaming URLs), a thumbnail URL, video duration, and input dimensions. The system persists these URLs and metadata on the video record so that client applications can later retrieve them for video playback.

**Why this priority**: Playback URLs are the final output of the video pipeline. Without storing them, the system has no way to serve videos to team members. This is the critical data that connects the upload pipeline to future playback features.

**Independent Test**: Send a Cloudflare webhook notification with playback URLs and thumbnail URL for a video in "processing" status. Verify the video record is updated with all URLs and metadata.

**Acceptance Scenarios**:

1. **Given** a Cloudflare webhook notification includes an HLS playback URL, **When** the system processes the notification, **Then** the HLS URL is stored on the video record.
2. **Given** a Cloudflare webhook notification includes a DASH playback URL, **When** the system processes the notification, **Then** the DASH URL is stored on the video record.
3. **Given** a Cloudflare webhook notification includes a thumbnail URL, **When** the system processes the notification, **Then** the thumbnail URL is stored on the video record.
4. **Given** a Cloudflare webhook notification includes video duration and input dimensions, **When** the system processes the notification, **Then** the duration, width, and height are stored on the video record.

---

### User Story 3 - Placeholder User Identity (Priority: P1)

Since user authentication is not yet implemented, the system assigns a constant placeholder user ID to all video uploads. This allows the data model to include user ownership from the start, making it straightforward to replace the placeholder with real user identities when authentication is implemented.

**Why this priority**: Including user ownership in the initial data model avoids a migration to add the column later. The placeholder approach is the simplest solution that keeps the schema correct while deferring authentication complexity.

**Independent Test**: Create multiple video records and verify they all have the same constant placeholder user ID.

**Acceptance Scenarios**:

1. **Given** a user creates a video upload, **When** the video record is created in the database, **Then** the record's user ID is set to the constant placeholder value.
2. **Given** the placeholder user ID is defined as a constant, **When** authentication is implemented in a future feature, **Then** the constant can be replaced without changing the database schema.

---

### Edge Cases

- What happens if ProcessVideo receives a BlobCreated event for a blob path that does not match any video record? The function should log a warning and skip the database update. The video may have been uploaded outside the system.
- What happens if CloudflareWebhook receives a notification for a Cloudflare video UID that does not match any video record? The function should log a warning and return a successful response. The video may have been submitted to Cloudflare outside the system.
- What happens if a webhook notification arrives for a video that is already in "ready" or "failed" status? The system should accept the notification idempotently. If the new status matches the current status, no update is needed. If it differs (e.g., a retry from Cloudflare), the system should update to the new status.
- What happens if the database is temporarily unavailable? The Azure Function should throw an exception, allowing the runtime to retry (for EventGrid triggers) or return a 500 error (for HTTP triggers). No special retry logic is needed beyond the platform's built-in mechanisms.
- What happens if ProcessVideo fails before submitting the video to Cloudflare? The video remains in "created" status. A future retry of the EventGrid event will attempt to process it again. The function is idempotent — re-processing a video already in "processing" status will re-submit to Cloudflare.

## Assumptions

- Features 001–004 are implemented: videos can be recorded, uploaded to blob storage, submitted to Cloudflare Stream for transcoding, and webhook notifications are received.
- Azure Database for PostgreSQL Flexible Server will be provisioned as the database. The decision to use PostgreSQL was made to support the future polyglot stack (Go/GORM, Rust/sea-orm, Elixir/Ecto).
- Entity Framework Core with the Npgsql provider will be used as the ORM for the .NET Azure Functions.
- The Function App's system-assigned managed identity will authenticate to PostgreSQL using Microsoft Entra ID — no database passwords.
- The constant placeholder user ID will be a well-known GUID (e.g., `00000000-0000-0000-0000-000000000001`) defined as a constant in the codebase.
- The CreateVideo endpoint response will be extended to include the video ID so client applications can track the video through its lifecycle.

## Out of Scope

- **User authentication and authorization**: Real user identity is deferred. All videos are assigned to the placeholder user.
- **Video listing or retrieval API**: Endpoints to list or fetch video records are deferred to a future feature.
- **Video playback**: Delivering video streams to client applications is a separate feature.
- **Database migrations in CI/CD**: Running EF Core migrations automatically during deployment is deferred. Migrations will be applied manually or via a separate task during this feature.
- **Connection pooling optimization**: PgBouncer or other connection pooling beyond EF Core's built-in pooling is deferred until load testing identifies a need.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provision an Azure Database for PostgreSQL Flexible Server using Bicep, configured with Microsoft Entra-only authentication (no password authentication).
- **FR-002**: The system MUST define a Video entity with fields for: ID (GUID primary key), user ID (GUID), blob path, content type, file size, status (created/uploaded/processing/ready/failed), Cloudflare video UID, HLS URL, DASH URL, thumbnail URL, duration, input width, input height, error reason code, error reason text, and timestamps (created, updated).
- **FR-003**: The CreateVideo function MUST create a new Video record with status "created" and the placeholder user ID when a valid upload request is received.
- **FR-004**: The CreateVideo function MUST return the video ID in the response so client applications can track the video.
- **FR-005**: The ProcessVideo function MUST look up the Video record by blob path when a BlobCreated event is received and update its status to "processing" after successfully submitting the video to Cloudflare Stream. The Cloudflare video UID MUST be stored on the record. The "uploaded" status is reserved for a future blob-upload-confirmed event and is not set in this implementation.
- **FR-006**: *(Merged into FR-005.)*
- **FR-007**: The CloudflareWebhook function MUST look up the Video record using a two-tier strategy: first by the video ID from the Cloudflare `meta` dictionary (primary key lookup), falling back to a lookup by Cloudflare video UID if the meta value is absent. The function MUST update the matched record with the playback URLs, thumbnail URL, duration, input dimensions, and status "ready" when the video is ready to stream.
- **FR-008**: The CloudflareWebhook function MUST update the Video record's status to "failed" and store the error details when Cloudflare reports a processing failure.
- **FR-009**: The Function App MUST authenticate to PostgreSQL using its system-assigned managed identity via Microsoft Entra ID.
- **FR-010**: The PostgreSQL Flexible Server MUST be provisioned via Bicep with Entra-only authentication, TLS enforcement, and appropriate firewall rules.
- **FR-011**: All new production code MUST have corresponding automated unit tests.

### Key Entities

- **Video**: The central entity representing a video in the Naked Standup system. Tracks the video from creation through upload, transcoding, and completion. Stores blob storage path, Cloudflare identifiers, playback URLs, and processing status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When a video upload is initiated via POST /api/video, a Video record is created in PostgreSQL with status "created" and the placeholder user ID.
- **SC-002**: When a blob upload completes and triggers ProcessVideo, the corresponding Video record's status is updated to "processing" with the Cloudflare video UID stored. The "uploaded" status is reserved for a future blob-upload-confirmed event.
- **SC-003**: When a Cloudflare webhook indicates a video is ready, the Video record is updated to status "ready" with all playback URLs, thumbnail, duration, and dimensions stored.
- **SC-004**: When a Cloudflare webhook indicates a failure, the Video record is updated to status "failed" with error details stored.
- **SC-005**: All database access uses the Function App's managed identity — no database passwords exist in configuration or source code.
- **SC-006**: All new code (entity, DbContext, service updates, function modifications) has corresponding unit tests with xUnit and Moq.
- **SC-007**: The PostgreSQL Flexible Server is fully provisioned via Bicep with no manual Azure portal configuration required.
