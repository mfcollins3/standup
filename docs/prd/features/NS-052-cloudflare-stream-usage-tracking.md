# NS-052: Cloudflare Stream usage tracking

[Back to the PRD](../README.md)

**Requirement ID:** NS-052

**User Story:** As a billing owner, I want to have my Cloudflare Stream usage attributed to my user or enterprise so that I am billed fairly for storage, transcoding and playback.

**Acceptance Criteria:**

- [ ] Every Stream video carries metadata that links it to a workspace, project and uploading user.
- [ ] The service records Stream storage minutes, encoded minutes and delivered (playback) minutes per workspace and per user, at least hourly.
- [ ] Usage is reconciled daily against Cloudflare's own analytics and bill, and differences above 1% raise an alert.
- [ ] Public and guest playback is attributed to the workspace that owns the report.
- [ ] Usage data feeds the usage meters in NS-036 and the dashboard in NS-038.
- [ ] Usage records are kept for at least 13 months.

**Technical Notes:** Combine Stream webhooks, the Stream video list API and Cloudflare's GraphQL analytics for minutes delivered. Confirm current Stream pricing and the exact metered dimensions.

**Priority:** Must-have
