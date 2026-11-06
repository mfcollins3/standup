# NS-017: Processing status and failure handling

[Back to the PRD](../README.md)

**Requirement ID:** NS-017

**User Story:** As a team member, I want to see whether my report is processing, ready or failed so that I know when it is available and can fix problems.

**Acceptance Criteria:**

- [ ] Each report shows a status: recording, queued, uploading, processing, ready or failed.
- [ ] Failed uploads or transcodes show a reason in plain language and a Retry action.
- [ ] Users and owners of the report can delete a failed report.
- [ ] Failures after maximum automatic retries create an alert for operations staff.
- [ ] Status updates appear in the apps without a manual refresh.

**Technical Notes:** Poll or use push/SignalR-style updates. Keep failure reasons in structured logs.

**Priority:** Must-have
