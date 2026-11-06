# NS-016: Start transcoding with Cloudflare Stream

[Back to the PRD](../README.md)

**Requirement ID:** NS-016

**User Story:** As a team member, I want to have my uploaded video prepared for streaming automatically so that stakeholders can watch it on any device.

**Acceptance Criteria:**

- [ ] After upload verification the service starts a Cloudflare Stream job from the blob (copy-from-URL or direct upload) and stores the Stream video ID.
- [ ] Cloudflare Stream webhooks update the report status when processing is ready or failed.
- [ ] Jobs are idempotent: a repeated completion call does not create duplicate Stream videos.
- [ ] Processing starts within 30 seconds of a verified upload, and a 30-second video is typically ready within 3 minutes.
- [ ] Videos are restricted to signed playback so that only authorized users or valid share links can play them.

**Technical Notes:** Use Cloudflare Stream API with requireSignedURLs and metadata tags carrying workspace, project and user IDs (needed for NS-052). Verify webhook signatures. Queue the work (e.g. Azure Service Bus) with retries and a dead-letter queue. The original upload stays in Azure Blob Storage for downloads, transcription and reprocessing.

**Priority:** Must-have
