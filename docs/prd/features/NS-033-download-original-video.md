# NS-033: Download original video

[Back to the PRD](../README.md)

**Requirement ID:** NS-033

**User Story:** As a team member, I want to download a report video so that I can keep a copy or use it elsewhere.

**Acceptance Criteria:**

- [ ] Authorized users can download a report as an MP4 if the workspace allows downloads.
- [ ] Admins can disable downloads.
- [ ] Downloads use short-lived authenticated URLs.
- [ ] Each download is metered and attributed for billing.
- [ ] Downloads are recorded in the audit log.

**Technical Notes:** Downloads come from the original in Azure Blob Storage through short-lived read SAS URLs. The original is also used for transcription, thumbnails, reprocessing and future features.

**Priority:** Should-have
