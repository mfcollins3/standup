# Feature Specification: Signed Video URLs for Secure Streaming

**Feature Branch**: `006-signed-video-urls`
**Created**: 2026-03-26
**Status**: Draft
**Input**: User description: "I want to lock down the Cloudflare videos to require signed URLs to be able to stream any of the videos from Cloudflare. The application will call an API with the video's id value and will receive the signed URL that the application can call to stream the video. The API should also accept the type of stream (HLS or DASH) to receive the signed URL for."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Retrieve Signed Streaming URL for a Video (Priority: P1)

A team member opens a video in the Naked Standup application. The application sends a request to the API with the video's internal identifier and the desired stream type (HLS or DASH). The API looks up the video, generates a time-limited signed URL from Cloudflare, and returns it. The application uses the signed URL to stream the video in the player. Because the signed URL expires after a short time, the video cannot be shared or accessed by unauthorized users.

**Why this priority**: This is the core capability of the feature. Without it, the application has no way to play videos once they are locked down with signed URL requirements. This user story delivers the complete end-to-end value: request a video, get a signed URL, stream it.

**Independent Test**: Call the API endpoint with a valid video ID and stream type "HLS". Verify the response contains a signed URL that can be used to load the HLS manifest. Repeat with stream type "DASH" and verify a DASH manifest URL is returned.

**Acceptance Scenarios**:

1. **Given** a video exists in the system with status "ready" and has a Cloudflare video UID, **When** the application requests a signed URL with stream type "HLS", **Then** the system returns a time-limited signed HLS manifest URL for the video.
2. **Given** a video exists in the system with status "ready" and has a Cloudflare video UID, **When** the application requests a signed URL with stream type "DASH", **Then** the system returns a time-limited signed DASH manifest URL for the video.
3. **Given** a video exists but is not in "ready" status, **When** the application requests a signed URL, **Then** the system returns an error indicating the video is not available for streaming.
4. **Given** no video exists with the provided ID, **When** the application requests a signed URL, **Then** the system returns a not-found error.

---

### User Story 2 - Lock Down Videos to Require Signed URLs on Upload (Priority: P1)

When a video is submitted to Cloudflare for transcoding, the system marks the video as requiring signed URLs. This ensures that all videos in the platform are protected from the moment they are uploaded. Public access URLs (such as the watch page or direct HLS/DASH manifest links using the video UID) will no longer work for any video.

**Why this priority**: This is equally critical because without locking down the videos on the Cloudflare side, the signed URL generation is meaningless — users could still access the videos through public URLs. This story and Story 1 together form the minimum viable security feature.

**Independent Test**: Upload a video through the existing pipeline. After Cloudflare processes it, attempt to access the video using the public HLS manifest URL (without a signed token). Verify the request is rejected. Then use a signed URL and verify the video streams successfully.

**Acceptance Scenarios**:

1. **Given** a video is being submitted to Cloudflare for transcoding, **When** the transcoding request is sent, **Then** the request includes the `requireSignedURLs` flag set to true.
2. **Given** a video has been processed by Cloudflare with signed URL requirements, **When** someone attempts to access the video using a public URL (without a signed token), **Then** Cloudflare rejects the request.
3. **Given** a video has been processed by Cloudflare with signed URL requirements, **When** a valid signed token is used in the URL, **Then** Cloudflare allows the video to be streamed.

---

### User Story 3 - Signed URL Expiration (Priority: P2)

Signed URLs are generated with a limited lifetime. After the token expires, the URL can no longer be used for streaming. This limits the window of exposure if a URL is inadvertently shared and ensures that continued access to video content requires fresh authorization from the system.

**Why this priority**: Expiration is important for security but has a reasonable default (1 hour). It builds on the core signed URL capability and provides defense-in-depth against URL sharing.

**Independent Test**: Generate a signed URL for a video. Verify the URL contains an expiration timestamp set to a limited duration in the future. After the expiration time passes, attempt to use the URL and verify Cloudflare rejects it.

**Acceptance Scenarios**:

1. **Given** the application requests a signed URL for a video, **When** the signed URL is generated, **Then** the URL includes an expiration time that limits how long it can be used.
2. **Given** a signed URL has been generated, **When** the expiration time has passed, **Then** the URL can no longer be used to stream the video.
3. **Given** a signed URL has been generated, **When** the URL is used before the expiration time, **Then** the video streams successfully.

---

### Edge Cases

- What happens when a video's Cloudflare UID is missing (e.g., the video was created but not yet submitted to Cloudflare)?
- What happens when the Cloudflare API is unreachable or returns an error during signed URL generation?
- What happens when an invalid stream type (neither HLS nor DASH) is specified in the request?
- What happens when the signed URL expires mid-stream (e.g., while a viewer is actively watching a long video)?
- What happens when the Cloudflare signing key has been revoked or rotated?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an API endpoint that accepts a video identifier and a stream type (HLS or DASH) and returns a signed URL for streaming the video.
- **FR-002**: System MUST validate that the requested video exists and is in "ready" status before generating a signed URL.
- **FR-003**: System MUST generate signed URLs with a limited expiration time.
- **FR-004**: System MUST return the appropriate manifest URL format based on the requested stream type — the HLS manifest URL for HLS requests. and the DASH manifest URL for DASH requests.
- **FR-005**: System MUST mark all videos as requiring signed URLs when they are submitted to Cloudflare for transcoding.
- **FR-006**: System MUST return a meaningful error when the requested video does not exist.
- **FR-007**: System MUST return a meaningful error when the requested video is not yet ready for streaming.
- **FR-008**: System MUST return a meaningful error when an unsupported stream type is requested.
- **FR-009**: System MUST securely store the Cloudflare signing key material used to generate tokens.

### Key Entities

- **Video**: An existing entity representing a recorded standup update. Key attributes relevant to this feature: internal ID, Cloudflare video UID, video status, HLS URL, DASH URL.
- **Signed URL Token**: A short-lived, cryptographically signed token that authorizes access to a specific video. Contains the video's Cloudflare UID, an expiration timestamp, and the signing key identifier.
- **Signing Key**: Credential material obtained from Cloudflare used to generate signed tokens. Consists of a key ID and private key. Must be stored securely and can be rotated.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All videos uploaded through the platform are protected and cannot be accessed via public URLs.
- **SC-002**: The application can generate a signed streaming URL and begin video playback within 2 seconds of the user requesting to watch a video.
- **SC-003**: 100% of expired signed URLs are rejected by the streaming service, preventing unauthorized access after the token lifetime.
- **SC-004**: The API correctly returns signed URLs for both HLS and DASH stream types for every ready video.

## Assumptions

- The existing video upload pipeline (CreateVideo, ProcessVideo, CloudflareWebhook) is operational and stores the Cloudflare video UID on the video record.
- Cloudflare Stream's signed URL feature is available on the current Cloudflare plan.
- The signing key for generating tokens will be provisioned from Cloudflare and stored securely in the application's configuration or secrets store.
- Token expiration duration will use a reasonable default (e.g., 1 hour) and does not need to be user-configurable in this iteration.
- The iOS application will handle signed URL expiration gracefully by requesting a new signed URL if the current one expires during a long viewing session.
- The system does not need to support access rules (e.g., geo-restrictions or IP-based restrictions) in this iteration; those can be added later as needed.
