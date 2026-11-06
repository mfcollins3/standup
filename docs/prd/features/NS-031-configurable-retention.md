# NS-031: Configurable retention

[Back to the PRD](../README.md)

**Requirement ID:** NS-031

**User Story:** As a workspace administrator, I want to set how long videos are kept so that I control storage cost and compliance.

**Acceptance Criteria:**

- [ ] The default retention for videos is 30 days.
- [ ] Retention can be set at enterprise, workspace, project and user levels, and the most restrictive applicable setting wins.
- [ ] The minimum retention is 7 days and there is no maximum; customers pay for storage used.
- [ ] Changing retention shows the number of reports affected before it is applied.
- [ ] Users are notified before their videos are deleted.
- [ ] Transcripts, summaries, chunks and vectors are always deleted when their video is deleted.

**Technical Notes:** Retention applies to the original in Azure Blob Storage, the Cloudflare Stream copy, and all derived data.

**Priority:** Must-have
