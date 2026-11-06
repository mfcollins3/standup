# NS-015: Direct upload with SAS URLs

[Back to the PRD](../README.md)

**Requirement ID:** NS-015

**User Story:** As a team member, I want to upload my recorded video directly to cloud storage so that uploads are fast and reliable.

**Acceptance Criteria:**

- [ ] The client requests an upload from the API, which authorizes the user and project and returns a short-lived, write-only SAS URL scoped to one blob.
- [ ] The client uploads the video directly to Azure Blob Storage with chunked, resumable block uploads.
- [ ] The client notifies the API when the upload completes; the API verifies the blob exists and records it.
- [ ] Expired SAS URLs are re-requested without user action.
- [ ] No storage account keys are exposed to clients.

**Technical Notes:** SAS expiry 15 to 60 minutes. Use user-delegation SAS where possible. Container is private, with CORS limited to the web app origin.

**Priority:** Must-have
