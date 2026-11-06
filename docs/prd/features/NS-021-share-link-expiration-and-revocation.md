# NS-021: Share link expiration and revocation

[Back to the PRD](../README.md)

**Requirement ID:** NS-021

**User Story:** As a team member, I want to set an expiry on share links and revoke them so that I control how long a report stays shared.

**Acceptance Criteria:**

- [ ] Users can set an expiry date and time when creating a share link, and workspace admins can set a maximum lifetime or a default expiry.
- [ ] Expired links show a clear message and stop playing video.
- [ ] Report authors and admins can list active links for a report, with creation date, expiry and view count.
- [ ] Revoking a link makes it stop working within 1 minute.
- [ ] Creating, expiring and revoking links are recorded in the audit log.

**Technical Notes:** Expiry is enforced when the playback token is minted. Tokens are short-lived (minutes), so expiry takes effect quickly even for a playing session.

**Priority:** Must-have
