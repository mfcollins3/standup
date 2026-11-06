# NS-045: Require sign-in to view reports

[Back to the PRD](../README.md)

**Requirement ID:** NS-045

**User Story:** As a workspace administrator, I want to require viewers to be signed in to play a report so that only people with an account can watch our videos.

**Acceptance Criteria:**

- [ ] Workspace and enterprise admins can set a policy that share links need a signed-in user (or SSO guest under NS-044).
- [ ] Individual authors can require sign-in on a per-link basis, unless the workspace policy is stricter.
- [ ] The most restrictive policy applies.
- [ ] Viewers who are not signed in are asked to sign in and are returned to the video afterwards.
- [ ] The share-link dialog shows the effective policy to the author.

**Technical Notes:** Policy evaluation happens in the API at token-minting time.

**Priority:** Must-have
