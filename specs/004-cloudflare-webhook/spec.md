# Feature Specification: Cloudflare Stream Webhook Endpoint

**Feature Branch**: `004-cloudflare-webhook`
**Created**: 2026-03-23
**Status**: Draft
**Input**: User description: "In spec 003, we delivered the status report video to Cloudflare to transcode for on-demand streaming. When Cloudflare is finished processing the video, it will call a webhook to notify Naked Standup whether the video was successfully processed or failed. We need to create an HTTP Azure Function that Cloudflare can call to notify us of the result of the video. For this story, only focus on implementing the webhook to complete the integration between Naked Standup and Cloudflare. The actual implementation of the webhook and storing video information will be implemented in the next story to drive the application further. For this feature, we only care about completing the communication back between Cloudflare and Naked Standup."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Receive Cloudflare Webhook Notification (Priority: P1)

After a video has been submitted to Cloudflare Stream for transcoding (Feature 003), Cloudflare processes the video and sends an HTTP webhook notification to Naked Standup when processing completes or fails. The system provides an HTTP endpoint that Cloudflare can call, verifies the notification is authentically from Cloudflare, acknowledges receipt, and logs the result. This story completes the communication loop between Cloudflare Stream and Naked Standup — the video was sent outbound in Feature 003, and now the result comes back inbound via this webhook.

**Why this priority**: This is the only story for this feature. Without a webhook endpoint, Naked Standup has no way to learn whether Cloudflare successfully transcoded a video or encountered a failure. This closes the integration loop opened in Feature 003 and is a prerequisite for any future feature that needs to know the transcoding result (e.g., playback, status display, error handling).

**Independent Test**: Can be fully tested by sending a properly signed HTTP POST request to the webhook endpoint with a Cloudflare Stream webhook payload. Verify the endpoint returns a successful response and logs the notification details (video UID, status, blob path). Also verify that unsigned or tampered requests are rejected.

**Acceptance Scenarios**:

1. **Given** Cloudflare Stream has finished processing a video, **When** Cloudflare sends a webhook notification to the Naked Standup endpoint, **Then** the system receives the request and returns a successful HTTP response.
2. **Given** a webhook notification arrives with a valid signature, **When** the system processes the request, **Then** the notification is accepted and the video identifier, processing status, and associated metadata are logged.
3. **Given** a webhook notification arrives without a valid signature, **When** the system evaluates the request, **Then** the request is rejected with an unauthorized response and the rejection is logged.
4. **Given** Cloudflare sends a notification indicating a video failed to process, **When** the system receives the notification, **Then** the failure status and error details are logged for operational visibility.
5. **Given** the webhook endpoint is deployed, **When** the system is running, **Then** the endpoint is reachable at a publicly accessible URL that can be configured in the Cloudflare Stream dashboard.

---

### User Story 2 - Validate Webhook Authenticity via Signature Verification (Priority: P1)

Cloudflare Stream signs webhook notifications using a shared secret. The system must verify the signature on each incoming webhook request to ensure the notification authentically originated from Cloudflare and has not been tampered with. This prevents unauthorized third parties from sending fake webhook notifications to the system.

**Why this priority**: Signature verification is critical for security. Without it, any party that discovers the webhook URL could send fabricated notifications claiming videos succeeded or failed. This is a security requirement that must ship with the initial endpoint.

**Independent Test**: Can be tested by sending webhook requests with valid signatures (computed using the configured signing secret) and verifying they are accepted, then sending requests with invalid or missing signatures and verifying they are rejected with an unauthorized response.

**Acceptance Scenarios**:

1. **Given** a webhook request includes a signature header, **When** the signature matches the expected value computed from the request body and the configured signing secret, **Then** the request is accepted.
2. **Given** a webhook request includes a signature header, **When** the signature does not match the expected value, **Then** the request is rejected with an unauthorized response.
3. **Given** a webhook request does not include a signature header, **When** the system evaluates the request, **Then** the request is rejected with an unauthorized response.
4. **Given** the signing secret is configured, **When** the system starts, **Then** the signing secret is loaded from secure configuration and is never logged or exposed in error messages.

---

### Edge Cases

- What happens if Cloudflare sends a duplicate webhook notification for the same video? The endpoint should accept and acknowledge it without error. Since this feature only logs the notification (actual processing deferred to the next story), duplicates are harmless.
- What happens if the webhook request body is empty or malformed JSON? The endpoint should return a bad request response and log the parsing failure.
- What happens if the webhook endpoint is temporarily unavailable? Cloudflare retries webhook deliveries automatically. The endpoint should be idempotent so retried deliveries are handled gracefully.
- What happens if the signing secret is not configured in the system? The endpoint should fail closed — reject all incoming webhook requests and log a configuration error. The system must not accept unsigned requests when the signing secret is missing.
- What happens if Cloudflare changes or rotates the webhook signing secret? The system must be updated with the new secret. During rotation, notifications signed with the old secret will be rejected until the new secret is configured. This is an operational procedure, not an application feature.
- What happens if the webhook payload contains a video UID that the system did not submit for transcoding? The endpoint should still accept the notification (as long as the signature is valid) and log it. Filtering unknown video UIDs is deferred to the next story when actual processing is implemented.

## Assumptions

- Feature 003 (Stream Video Transcoding) has been implemented — videos are being submitted to Cloudflare Stream for transcoding, and Cloudflare Stream returns a video UID that identifies each transcoding job.
- Cloudflare Stream webhooks are configured in the Cloudflare dashboard to point at the Naked Standup webhook endpoint URL. This is a manual configuration step outside the scope of this feature's implementation.
- Cloudflare Stream webhook notifications are sent as HTTP POST requests with a JSON body containing the video status and metadata, and a signature header (`Webhook-Signature`) for authenticity verification.
- The webhook signing secret is provided by Cloudflare when webhooks are configured and will be stored securely (e.g., in Azure Key Vault or application configuration) — never in source code.
- The webhook endpoint runs in the same Azure Functions app that hosts the existing `CreateVideo` and `ProcessVideo` functions.
- This feature intentionally limits scope to receiving, validating, and logging webhook notifications. Persisting video status, updating records, or triggering downstream actions are deferred to the next feature.

## Out of Scope

- **Persisting video processing results**: Storing the transcoding result (success/failure, playback URLs, video metadata) to a database or storage. This will be implemented in the next story.
- **Updating video status records**: Changing the status of a video record from "processing" to "ready" or "failed" based on the webhook notification. Deferred to the next story.
- **Triggering downstream notifications**: Notifying team members or the iOS app that a video is ready for playback. This is a separate future feature.
- **Automatic Cloudflare webhook configuration**: Programmatically registering the webhook URL with Cloudflare. The webhook URL is configured manually in the Cloudflare dashboard.
- **Webhook retry management**: Building custom retry logic on the Naked Standup side. Cloudflare handles retries for failed webhook deliveries natively.
- **Playback integration**: Delivering transcoded video streams to clients. The webhook only confirms the transcoding outcome.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose a publicly accessible HTTP endpoint that accepts POST requests from Cloudflare Stream as webhook notifications.
- **FR-002**: The webhook endpoint MUST verify the authenticity of each incoming request by validating the webhook signature header against the configured signing secret.
- **FR-003**: The webhook endpoint MUST reject requests with missing or invalid signatures by returning an unauthorized HTTP response.
- **FR-004**: The webhook endpoint MUST parse the JSON request body to extract the video identifier, processing status, and any error details from the Cloudflare Stream notification payload.
- **FR-005**: The webhook endpoint MUST return a successful HTTP response to Cloudflare for valid, authenticated requests to acknowledge receipt of the notification.
- **FR-006**: The webhook endpoint MUST return a bad request HTTP response when the request body is empty or contains malformed JSON.
- **FR-007**: The system MUST log each received webhook notification with the video identifier, processing status (e.g., ready, error), and associated metadata (e.g., blob path from video meta).
- **FR-008**: The system MUST log rejected webhook requests (invalid signature, malformed body) with sufficient detail for operational troubleshooting without exposing the signing secret.
- **FR-009**: The webhook signing secret MUST be stored in secure configuration and MUST NOT be hard-coded in source code or committed to version control.
- **FR-010**: The webhook endpoint MUST handle duplicate notifications gracefully — accepting and acknowledging repeated deliveries of the same notification without error.
- **FR-011**: When the signing secret is not configured, the webhook endpoint MUST reject all incoming requests and log a configuration error. The endpoint MUST NOT accept unsigned requests as a fallback.

### Key Entities

- **Webhook Notification**: An HTTP POST request sent by Cloudflare Stream to the Naked Standup endpoint. Contains a JSON body with the video processing result and a signature header for authenticity verification. Associated with exactly one video identified by its Cloudflare video UID.
- **Webhook Signature**: A cryptographic signature included in the request header by Cloudflare. Computed from the request body and a shared signing secret. Used by the system to verify the notification is authentic and untampered.
- **Signing Secret**: A shared secret provided by Cloudflare when webhooks are configured. Stored securely in the system's configuration. Never exposed in logs, error messages, or source code.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of webhook notifications with valid signatures are accepted and acknowledged with a successful response.
- **SC-002**: 100% of webhook requests with invalid or missing signatures are rejected with an unauthorized response.
- **SC-003**: Every accepted webhook notification is logged with the video identifier, processing status, and metadata within the same request lifecycle.
- **SC-004**: The webhook endpoint responds to Cloudflare within 5 seconds for all requests to avoid Cloudflare treating the delivery as failed.
- **SC-005**: The webhook endpoint is operational and reachable immediately after deployment without requiring additional manual steps beyond configuring the URL in Cloudflare's dashboard.
- **SC-006**: All rejected requests (invalid signature, malformed body, missing configuration) are logged with enough detail to diagnose the issue without accessing Cloudflare's dashboard.
