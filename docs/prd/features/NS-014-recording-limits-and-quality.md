# NS-014: Recording limits and quality

[Back to the PRD](../README.md)

**Requirement ID:** NS-014

**User Story:** As a workspace administrator, I want to enforce a maximum report length and sensible video quality so that storage and processing costs stay predictable.

**Acceptance Criteria:**

- [ ] The maximum report length is 5 minutes in all apps and is enforced again by the server.
- [ ] Uploads longer than the limit or above the maximum file size are rejected with a clear error.
- [ ] A video's duration and format are validated after upload.
- [ ] Typical 30-second reports upload with a file size no larger than a documented target.

**Technical Notes:** Server-side validation is authoritative. Limits are configuration values.

**Priority:** Must-have
