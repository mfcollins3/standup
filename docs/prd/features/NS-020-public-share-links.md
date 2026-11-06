# NS-020: Public share links

[Back to the PRD](../README.md)

**Requirement ID:** NS-020

**User Story:** As a team member, I want to share a status report with a link that anyone can open so that people without an account can watch it.

**Acceptance Criteria:**

- [ ] Authorized users can create a share link for a report from the web and mobile apps and copy it or use the system share sheet.
- [ ] Links use unguessable tokens of at least 128 bits of entropy.
- [ ] Workspace policy can disable public links; the share option is then hidden.
- [ ] Share links stop working when the report is deleted or expires under retention policy.
- [ ] Playback through a link counts toward usage billing.
- [ ] Unless the workspace or the author requires sign-in (NS-045), anyone with the link can watch the video without signing in; no other workspace data is exposed.

**Technical Notes:** Link resolves to a public watch page that mints a short-lived signed Stream token. Add rate limiting and bot protection.

**Priority:** Must-have
