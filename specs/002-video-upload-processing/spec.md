# Feature Specification: Upload Status Video for Processing

**Feature Branch**: `002-video-upload-processing`
**Created**: 2026-03-22
**Status**: Draft
**Input**: User description: "Once a status report video has been recorded and approved by the user, the video needs to be uploaded to a server for transcoding for streaming playback, generating captions and transcripts, and other processing."

## User Scenarios & Testing

### User Story 1 - Submit Approved Video for Upload (Priority: P1)

As a team member who has just recorded and approved a status video, I want to submit it for upload so that my team can watch my update at their convenience.

After approving the recorded video on the review screen, the user taps a submit button. The system begins uploading the video to the server in the background. The user sees clear progress indication showing that the upload is underway. Once the upload completes successfully, the user receives confirmation that their video has been submitted.

**Why this priority**: This is the core value of the feature — without the ability to upload the approved video, none of the downstream processing (transcoding, captions, transcripts) can occur. This bridges the gap between the recording feature and the rest of the platform.

**Independent Test**: Can be fully tested by recording a video, approving it, tapping submit, and verifying the video is received by the server. Delivers a submitted status video ready for processing.

**Acceptance Scenarios**:

1. **Given** the user has approved a recorded video on the review screen, **When** they tap the submit button, **Then** the system begins uploading the video to the server and displays upload progress.
2. **Given** an upload is in progress, **When** the upload completes successfully, **Then** the user sees a confirmation that their video has been submitted.
3. **Given** the user has tapped submit, **When** the upload is in progress, **Then** the user can continue using the app while the upload proceeds in the background.

---

### User Story 2 - See Upload Progress (Priority: P1)

As a team member submitting a video, I want to see how the upload is progressing so that I know whether to wait or move on to other tasks.

While the video is uploading, the user sees a progress indicator showing the current state of the upload. The indicator conveys whether the upload has started, is actively transferring, or has completed. If the upload is taking longer than expected (e.g., on a slow connection), the user has enough information to decide whether to wait.

**Why this priority**: Progress visibility is essential to the upload experience. Without it, users cannot distinguish between an active upload and a stalled or failed one, leading to confusion and duplicate submissions.

**Independent Test**: Can be tested by initiating a video upload on varying network speeds and verifying the progress indicator updates throughout the process.

**Acceptance Scenarios**:

1. **Given** a video upload has started, **When** the user views the upload status, **Then** they see a progress indicator showing the upload is active.
2. **Given** a video upload is actively transferring data, **When** progress is made, **Then** the progress indicator updates to reflect the current upload state.
3. **Given** a video upload completes, **When** the user views the upload status, **Then** the progress indicator shows a completed state with a success confirmation.

---

### User Story 3 - Recover from Upload Failure (Priority: P1)

As a team member whose upload failed due to a network issue or server error, I want to retry the upload without re-recording my video so that I don't lose my work.

If the upload fails for any reason, the user is notified with a clear message explaining that the upload did not succeed. The recorded video is preserved on the device. The user can retry the upload from where they are without having to re-record the video. The system automatically retries transient failures before surfacing an error to the user.

**Why this priority**: Upload reliability directly impacts user trust. If a user loses their recording due to a network hiccup, they will lose confidence in the platform. Retry capability is essential for a robust upload experience.

**Independent Test**: Can be tested by simulating a network failure during upload and verifying the user is notified, the video is preserved, and a retry option is available.

**Acceptance Scenarios**:

1. **Given** a video upload is in progress, **When** a transient network error occurs, **Then** the system automatically retries the upload without user intervention.
2. **Given** automatic retries have been exhausted, **When** the upload still fails, **Then** the user sees a clear error message and a retry button.
3. **Given** an upload has failed and the user sees the error, **When** they tap the retry button, **Then** the system attempts to upload the same video again.
4. **Given** an upload has failed, **When** the user returns to the app later, **Then** the pending video is still available for retry and has not been deleted.

---

### User Story 4 - Server Initiates Video Processing (Priority: P2)

As a platform, once a video has been successfully received, the system needs to initiate processing so that the video becomes available for streaming playback with captions and transcripts.

When the server receives a completed video upload, it acknowledges receipt and initiates downstream processing. This processing includes transcoding the video for adaptive streaming playback, generating captions and transcripts from the audio, and any other required post-processing. The user does not need to take any action — processing happens automatically after upload.

**Why this priority**: Processing is the reason the upload exists, but it happens entirely on the server side after the upload succeeds. The user's primary interaction is with the upload flow (P1 stories). Server-side processing is essential but secondary to a working upload experience.

**Independent Test**: Can be tested by uploading a video and verifying that the server acknowledges receipt and that processing tasks are initiated (transcoding, caption generation).

**Acceptance Scenarios**:

1. **Given** a video upload completes successfully on the server, **When** the server acknowledges receipt, **Then** the system initiates video transcoding for streaming playback.
2. **Given** a video upload completes successfully on the server, **When** the server acknowledges receipt, **Then** the system initiates caption and transcript generation from the video's audio.
3. **Given** processing has been initiated, **When** the user checks back later, **Then** the video's processing status is available (e.g., processing, ready, failed).

---

### User Story 5 - Cancel a Pending Upload (Priority: P3)

As a team member who changed their mind about their recording, I want to cancel a pending upload so that an unwanted video is not shared with my team.

While an upload is in progress or queued, the user can cancel it. Canceling stops the upload, removes the video from the upload queue, and preserves the recorded video on the device so the user can re-record or discard it.

**Why this priority**: Cancellation is a safety net that improves user control. The core upload and retry flows are more critical, but cancellation prevents unwanted videos from being shared.

**Independent Test**: Can be tested by starting an upload, tapping cancel before it completes, and verifying the upload stops and no video is submitted to the server.

**Acceptance Scenarios**:

1. **Given** a video upload is in progress, **When** the user taps cancel, **Then** the upload stops and no video is submitted to the server.
2. **Given** the user has canceled an upload, **When** they return to the review screen, **Then** the recorded video is still available for playback, re-recording, or re-submitting.

---

### Edge Cases

- What happens when the user has no network connectivity at the time of submission? The system should inform the user that they are offline and queue the upload to be attempted when connectivity is restored.
- What happens if the app is terminated (force quit or crash) during an upload? The recorded video should remain on the device, and the upload should be retried when the app is next launched.
- What happens if the device runs out of battery during an upload? The system should handle this gracefully; the video remains on the device and can be re-uploaded when the device is charged and the app reopened.
- What happens if the server rejects the uploaded video (e.g., corrupt file, unsupported format)? The user should be notified that the video could not be processed, with guidance on re-recording if needed.
- What happens if the user submits a video and then immediately records and submits a new one? Each upload should be handled independently, and both videos should be processed separately.
- What happens if the upload succeeds but server-side processing fails (e.g., transcoding error)? The user should be notified that their video was received but could not be processed, and the system should automatically retry processing.
- What happens if the user is on a metered or slow cellular connection? On the first upload attempt over a cellular connection, the system prompts the user to choose whether to allow cellular uploads. The user's choice is saved in app settings and can be changed later. If cellular uploads are not permitted, the upload is queued until a Wi-Fi connection is available.

## Clarifications

### Session 2026-03-22

- Q: Which level of background upload behavior is required — iOS URLSession background transfers (survives app suspension/termination) or in-app background only? → A: iOS background transfers using URLSession background configuration.
- Q: Where should the iOS client upload the video file? → A: Azure Blob Storage via SAS URL — client requests a short-lived SAS URL from the backend API, then uploads directly to Blob Storage.
- Q: What should the default cellular upload policy be? → A: Prompt once, remember preference — on first cellular upload, ask the user whether to allow cellular uploads and remember the choice in app settings.
- Q: What is explicitly out of scope for this feature? → A: All listed — real-time push notifications for processing completion, video editing/trimming before upload, viewer-side playback of processed videos, and admin dashboard for monitoring processing jobs.
- Q: What authentication/authorization model should protect the upload flow? → A: Authenticated SAS URL generation — backend requires a valid API key to issue a SAS URL scoped to a single blob path with short expiry (~15 min) and write and create access. OAuth 2.0 + JWT authentication is deferred to a future story.

## Out of Scope

The following are explicitly excluded from this feature and will be addressed in separate features if needed:

- **Real-time push notifications** for processing completion (e.g., notifying the user when transcoding finishes). Processing status is available via polling when the user checks back.
- **Video editing or trimming** before upload. The video is uploaded as-is from the recording feature.
- **Viewer-side playback** of processed videos. This feature covers upload and server-side processing only; playback is a separate feature.
- **Admin dashboard** for monitoring processing jobs. Server-side observability is an operational concern, not part of this user-facing feature.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST allow the user to submit an approved recorded video for upload from the review screen.
- **FR-001a**: The system MUST request a short-lived SAS (Shared Access Signature) URL from the backend API before initiating the upload.
- **FR-001b**: The system MUST upload the video file directly to Azure Blob Storage using the SAS URL.
- **FR-002**: The system MUST upload the video to the server using iOS URLSession background transfers, allowing the upload to continue even when the app is suspended or terminated by the OS.
- **FR-003**: The system MUST display a progress indicator during the upload that reflects the current upload state (pending, uploading, retrying, completed, failed, cancelled).
- **FR-004**: The system MUST automatically retry transient upload failures (network timeouts, temporary server errors) before surfacing an error to the user.
- **FR-005**: The system MUST preserve the recorded video on the device if an upload fails, allowing the user to retry without re-recording.
- **FR-006**: The system MUST provide a manual retry option when an upload fails after automatic retries are exhausted.
- **FR-007**: The system MUST allow the user to cancel a pending or in-progress upload.
- **FR-008**: The system MUST notify the user when an upload completes successfully.
- **FR-009**: The system MUST notify the user when an upload fails permanently, with a clear error message.
- **FR-010**: The server MUST acknowledge receipt of a completed video upload and initiate processing (transcoding, caption generation, transcript generation). Upload completion is detected via Azure Blob Storage event triggers.
- **FR-015**: The system MUST queue uploads when the device is offline and attempt them when connectivity is restored.
- **FR-016**: The system MUST persist pending uploads across app restarts using URLSession background transfer capabilities so that uploads are not lost if the app is terminated or suspended.
- **FR-017**: The system MUST prompt the user on the first upload attempt over a cellular connection to choose whether to allow cellular uploads, and persist that preference in app settings.
- **FR-018**: The system MUST queue uploads when cellular uploads are not permitted and the device is on a cellular-only connection, resuming when Wi-Fi is available.
- **FR-019**: The backend MUST require a valid API key before issuing a SAS URL for video upload. OAuth 2.0 + JWT authentication is deferred to a future story.
- **FR-020**: The backend MUST issue SAS URLs that are scoped to a single blob path, have a short expiry (approximately 15 minutes), and grant write and create access.

### Deferred Requirements

The following requirements are essential to the overall video upload and processing workflow but are **deferred to a follow-on feature** (server-side video processing). They are documented here for traceability but are explicitly out of scope for implementation in this feature. The Event Grid trigger infrastructure (FR-010, T025) is in scope to prepare for these requirements.

- **FR-011** (deferred): The server MUST transcode uploaded videos into formats suitable for adaptive streaming playback.
- **FR-012** (deferred): The server MUST generate captions from the audio track of uploaded videos.
- **FR-013** (deferred): The server MUST generate text transcripts from the audio track of uploaded videos.
- **FR-014** (deferred): The system MUST make the processing status of a submitted video available to the user (e.g., processing, ready, failed).

### Key Entities

- **Video Upload**: Represents the transfer of a recorded video from the user's device to the server. Has a status (pending, uploading, retrying, completed, failed, cancelled), progress information, and a reference to the recorded video. Associated with exactly one recorded video.
- **Recorded Video**: The locally stored video file that was captured and approved by the user. Exists on the device until the upload is confirmed or the user explicitly discards it. Created by the recording feature (Feature 001).
- **Processing Job**: Represents the server-side work initiated after a video is received. Includes transcoding, caption generation, and transcript generation. Has a status (pending, processing, completed, failed) and is associated with exactly one uploaded video.
- **Transcript**: A text representation of the spoken content in the video, generated from the audio track. Associated with one processing job and one uploaded video.
- **Caption**: Time-coded text overlay generated from the audio track for accessibility and viewer convenience. Associated with one processing job and one uploaded video.

## Assumptions

- The recording feature (Feature 001 - Record Status Report Video) is complete and provides an approved video file on the device ready for upload.
- Users are authenticated before they can submit a video. Authentication is handled by a separate feature and is assumed to be in place.
- The server infrastructure for receiving uploads, transcoding, and generating captions/transcripts exists or will be built as part of implementing this feature.
- Video files from 30-second recordings are small enough to upload over typical mobile connections within a reasonable time frame (expected to be under 50 MB).
- The platform will define acceptable video formats and quality settings; the recording feature produces videos in a compatible format.
- Transcoding produces multiple quality levels for adaptive streaming (e.g., different resolutions and bitrates) so that viewers on varying network conditions can watch smoothly.
- Caption and transcript generation uses speech-to-text processing. The accuracy of generated captions is expected to be sufficient for comprehension but may not be perfect for all accents or audio conditions.
- The system does not require real-time processing — there is an acceptable delay between upload and the video being ready for streaming with captions. A target of minutes (not hours) is assumed.
- Only one upload per recorded video is expected at a time. The system does not need to handle concurrent uploads of the same video.
- Background uploads use URLSession background transfer services, which are managed by the iOS operating system and continue even when the app is suspended or terminated.
- Video files are uploaded directly to Azure Blob Storage using short-lived SAS URLs issued by the backend API. This avoids routing large files through the API layer and leverages Azure's scalable storage infrastructure. Server-side processing is triggered by Blob Storage events upon upload completion.
- SAS URLs issued by the backend are scoped to a single blob path, expire after approximately 15 minutes, and grant write and create access. The backend only issues SAS URLs to authenticated users, ensuring unauthorized uploads are not possible.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can submit a video for upload within 5 seconds of approving it on the review screen (time from tap to upload initiated).
- **SC-002**: 95% of video uploads complete successfully on the first attempt when the device has a stable network connection.
- **SC-003**: Users are notified of upload completion or failure within 5 seconds of the event occurring.
- **SC-004**: Failed uploads can be retried without re-recording, and 99% of retried uploads eventually succeed.
- **SC-005** (deferred): Uploaded videos are transcoded and available for streaming playback within 5 minutes of upload completion. *(Depends on deferred FR-011; measured once server-side processing is implemented.)*
- **SC-006** (deferred): Captions and transcripts are generated and available within 5 minutes of upload completion. *(Depends on deferred FR-012/FR-013; measured once server-side processing is implemented.)*
- **SC-007**: Uploads queued while offline are automatically submitted within 30 seconds of connectivity being restored.
- **SC-008**: No submitted video is lost due to app termination, device restart, or transient network failure.
