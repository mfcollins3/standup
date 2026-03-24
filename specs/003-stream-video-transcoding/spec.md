# Feature Specification: Stream Video Transcoding via Cloudflare Stream

**Feature Branch**: `003-stream-video-transcoding`
**Created**: 2026-03-23
**Status**: Draft
**Input**: User description: "When a video is uploaded to Azure Blob Storage, an Event Grid event will be published (currently commented out in infra/modules/storage.bicep; it was put in here as a placeholder, but I commented it out because it was preventing deployment). We want to capture this event, create an SAS URL for reading, and send that URL to Cloudflare Stream using the Upload Videos from a URL API. Cloudflare Stream will then download the video from Blob Storage and will transcode the video for on-demand streaming playback."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatically Transcode Uploaded Video (Priority: P1)

After a team member uploads a status video to the platform, the system automatically detects the new upload and submits the video to a transcoding service for processing. The team member does not need to take any action — the transcoding is triggered seamlessly by the upload event. Once transcoding begins, the video is queued with the transcoding provider and will be prepared for on-demand streaming playback.

**Why this priority**: This is the core value of the feature. Without automatic detection and submission to the transcoding service, uploaded videos remain raw files in storage and can never be played back by other team members. This story connects the upload pipeline (Feature 002) to the streaming delivery pipeline, making uploaded videos useful.

**Independent Test**: Can be fully tested by uploading a video to the `status-videos` container, verifying the system detects the upload event, generates a read URL for the video, and successfully submits it to the transcoding service. The transcoding service acknowledges receipt and begins processing.

**Acceptance Scenarios**:

1. **Given** a video has been uploaded to the `status-videos` container, **When** the upload completes, **Then** the system detects the new blob via an event notification within 60 seconds.
2. **Given** the system has detected a new video upload event, **When** it processes the event, **Then** it generates a time-limited read URL for the uploaded blob.
3. **Given** the system has a read URL for the uploaded video, **When** it submits the URL to the transcoding service, **Then** the transcoding service accepts the submission and begins downloading the video.
4. **Given** the transcoding service has accepted the video submission, **When** transcoding completes, **Then** the video is available for on-demand streaming playback.

---

### User Story 2 - Recover from Transcoding Submission Failure (Priority: P1)

If the system fails to submit an uploaded video to the transcoding service (e.g., the transcoding service is temporarily unavailable or the request is rejected), the system retries the submission automatically. Transient failures do not cause videos to be lost or permanently stuck in an unprocessed state.

**Why this priority**: Reliability of the processing pipeline is critical. If a single transient error causes a video to never be transcoded, the team member's update is lost to their colleagues. Retry logic is essential for a production-ready pipeline.

**Independent Test**: Can be tested by simulating a failure in the transcoding service submission (e.g., the service returns a server error), verifying the system retries automatically, and confirming the video is eventually submitted when the service recovers.

**Acceptance Scenarios**:

1. **Given** the system attempts to submit a video to the transcoding service, **When** the submission fails with a transient error (e.g., timeout, service unavailable), **Then** the system retries the submission automatically.
2. **Given** the system is retrying a failed submission, **When** the transient error resolves, **Then** the video is successfully submitted to the transcoding service.
3. **Given** the system has exhausted all retry attempts, **When** the submission still fails, **Then** the failure is logged with enough detail to diagnose the issue and the event is sent to a dead-letter destination.

---

### User Story 3 - Track Video Processing Status (Priority: P2)

After a video has been submitted to the transcoding service, the system tracks the processing status so that downstream features (e.g., playback, notification) can determine when a video is ready for streaming.

**Why this priority**: While the core submission pipeline (P1) is the immediate deliverable, tracking the processing status is essential for any downstream consumer to know when the video is ready. Without it, there is no way to know when a video can be played back.

**Independent Test**: Can be tested by submitting a video for transcoding and verifying that the system records the transcoding job identifier and can report the current status (e.g., queued, processing, ready, error).

**Acceptance Scenarios**:

1. **Given** the system has submitted a video to the transcoding service, **When** the submission succeeds, **Then** the system records the transcoding job identifier associated with the uploaded video.
2. **Given** a transcoding job is in progress, **When** the status of the job is queried, **Then** the current processing state is returned (e.g., queued, processing, ready, error).
3. **Given** transcoding has completed, **When** the status is queried, **Then** the system reports the video as ready for playback and provides the streaming playback information.

---

### User Story 4 - Enable Event Grid Infrastructure for Blob Upload Events (Priority: P1)

The infrastructure that publishes events when a video is uploaded to blob storage needs to be enabled. Currently, the Event Grid system topic and event subscription resources are defined but commented out in the infrastructure templates because they were blocking deployment. The infrastructure must be updated so that blob-created events in the `status-videos` container are reliably published and delivered to the processing function.

**Why this priority**: Without the event infrastructure in place, no upload events are raised and the entire processing pipeline cannot trigger. This is a prerequisite for all other stories.

**Independent Test**: Can be tested by deploying the updated infrastructure, uploading a blob to the `status-videos` container, and verifying that the event is delivered to the configured endpoint.

**Acceptance Scenarios**:

1. **Given** the Event Grid system topic and event subscription are deployed, **When** a blob is created in the `status-videos/uploads/` path, **Then** a `BlobCreated` event is delivered to the processing function endpoint.
2. **Given** the Event Grid infrastructure is deployed, **When** the overall infrastructure deployment runs, **Then** deployment completes successfully without errors.
3. **Given** the event subscription is configured, **When** an event delivery fails, **Then** the event is retried according to the configured retry policy and eventually sent to a dead-letter destination if all retries are exhausted.

---

### Edge Cases

- What happens if the same blob-created event is delivered more than once? The processing function must handle duplicate events idempotently — if a video has already been submitted for transcoding, a duplicate event should not trigger a second submission.
- What happens if the read URL expires before the transcoding service finishes downloading the video? The read URL must have a sufficient expiry window to allow the transcoding service to begin its download. A generous expiry (e.g., 1 hour) mitigates this risk without compromising security since the URL is only shared with the transcoding service via a server-to-server call.
- What happens if the uploaded blob is deleted from storage before the transcoding service downloads it? The transcoding submission will fail. The system should log this as a permanent failure since the source video no longer exists.
- What happens if the Event Grid subscription endpoint is unreachable during deployment (validation handshake fails)? The deployment will fail. The processing function must be deployed and reachable before the Event Grid subscription is created, or the subscription must use a mechanism that does not require endpoint validation at deployment time.
- What happens if the blob-created event is for a non-video file (e.g., someone uploads a text file via the storage API)? The processing function should validate the content type of the blob. If it is not a supported video format, the event should be acknowledged without submitting for transcoding.
- What happens if the transcoding service is down for an extended period? Events that cannot be delivered after all retries should be dead-lettered. An operational alert should be triggered when the dead-letter queue depth exceeds a threshold.
- What happens if a very large video is uploaded that exceeds the transcoding service's size limits? The processing function should validate the blob size before submission and reject files that exceed the transcoding service's limits, logging the rejection.

## Assumptions

- Feature 002 (Video Upload Processing) has been implemented — the iOS client can upload videos to the `status-videos/uploads/` path in Azure Blob Storage via SAS URL.
- The existing `SasUrlService` generates write+create SAS URLs. This feature requires generating read SAS URLs for a different purpose (allowing the transcoding service to download the video). The existing service will need to be extended or a new method added.
- The transcoding service account and credentials are available and can be stored securely (e.g., in Azure Key Vault).
- The transcoding service supports receiving a URL pointing to the source video and will download it for transcoding (URL-based upload).
- Videos uploaded to the platform are short-form (30 seconds to a few minutes) and under 50 MB, well within the transcoding service's limits.
- The processing function runs in the same Azure Functions app that hosts the existing `CreateVideo` function.
- The read SAS URL shared with the transcoding service is only transmitted via a server-to-server HTTPS call and is never exposed to end users.

## Out of Scope

- **Playback integration**: Delivering transcoded video streams to the iOS client for playback. This feature covers submission to the transcoding service only; playback is a separate feature.
- **Caption and transcript generation**: Generating captions or transcripts from the video audio. This may be handled by the transcoding service or a separate service, but is not part of this feature.
- **Webhook processing from transcoding service**: Handling callbacks or webhooks from the transcoding service when transcoding completes. This may be part of a follow-on feature to update video status in real time.
- **Video deletion**: Removing uploaded videos from blob storage after transcoding is complete. Retention policy is a separate concern.
- **User-facing processing status UI**: Displaying processing status in the iOS app. This feature covers server-side status tracking only.
- **Multi-region or CDN delivery**: Configuring content delivery or multi-region streaming. The transcoding service handles delivery natively.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST detect when a new video blob is created in the `status-videos/uploads/` path in blob storage by receiving an event notification.
- **FR-002**: The system MUST generate a time-limited read URL for the uploaded video blob so that the transcoding service can download it.
- **FR-003**: The read URL MUST expire after a limited time window sufficient for the transcoding service to begin downloading (approximately 1 hour).
- **FR-004**: The system MUST submit the read URL to the transcoding service's URL-based upload endpoint to initiate transcoding for on-demand streaming playback.
- **FR-005**: The system MUST include required authentication credentials when calling the transcoding service API.
- **FR-006**: The transcoding service credentials MUST be stored securely and MUST NOT be hard-coded in source code or configuration files.
- **FR-007**: The system MUST automatically retry transient failures when submitting to the transcoding service (e.g., timeouts, 5xx errors) before treating the submission as permanently failed.
- **FR-008**: The system MUST handle duplicate event delivery idempotently — processing the same blob-created event more than once MUST NOT result in duplicate transcoding submissions.
- **FR-009**: The system MUST log each video processing attempt with the blob path, transcoding job identifier (on success), and error details (on failure).
- **FR-010**: The system MUST validate that the uploaded blob is a supported video format before submitting it for transcoding. Unsupported files MUST be acknowledged and skipped.
- **FR-011**: The system MUST record the transcoding job identifier returned by the transcoding service so that the video's processing status can be tracked.
- **FR-012**: The Event Grid system topic MUST be deployed to monitor the storage account for `BlobCreated` events.
- **FR-013**: The Event Grid event subscription MUST filter events to only the `status-videos/uploads/` path within the `status-videos` container.
- **FR-014**: The Event Grid event subscription MUST deliver events to the processing function endpoint.
- **FR-015**: The Event Grid event subscription MUST have a retry policy and dead-letter destination for events that cannot be delivered after all retry attempts.
- **FR-016**: The infrastructure deployment MUST succeed without errors when the Event Grid resources are included.

### Key Entities

- **Video Upload Event**: Represents the notification that a new video blob has been created in storage. Contains the blob path, blob URL, content type, and content length. Triggers the processing pipeline.
- **Read URL**: A time-limited, read-only URL for the uploaded video blob. Generated by the system and shared with the transcoding service via a server-to-server call. Expires after a configured window (approximately 1 hour).
- **Transcoding Job**: Represents the transcoding work initiated with the transcoding service. Has an identifier assigned by the transcoding service, a status (queued, processing, ready, error), and is associated with exactly one uploaded video blob.
- **Processing Record**: An internal record that associates the uploaded blob path with the transcoding job identifier and tracks submission status (submitted, failed, dead-lettered). Used for idempotency checks and status tracking.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 99% of videos uploaded to the `status-videos` container trigger a transcoding submission within 2 minutes of upload completion.
- **SC-002**: 95% of transcoding submissions succeed on the first attempt when the transcoding service is healthy.
- **SC-003**: Transient submission failures are automatically retried, and 99% of videos are eventually submitted within 10 minutes of upload.
- **SC-004**: No video is submitted for transcoding more than once due to duplicate event delivery.
- **SC-005**: Transcoded videos are available for on-demand streaming playback within 10 minutes of upload completion for videos under 50 MB.
- **SC-006**: All submission failures (transient and permanent) are logged with sufficient detail to diagnose the root cause without accessing the transcoding service's dashboard.
- **SC-007**: Infrastructure deployment including Event Grid resources completes successfully in all environments (development, staging, production).
