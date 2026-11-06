# NS-008: Invite and manage members

[Back to the PRD](../README.md)

**Requirement ID:** NS-008

**User Story:** As a workspace administrator, I want to invite people by email and remove them so that I can manage who is on my team.

**Acceptance Criteria:**

- [ ] Admins can invite people by email with a role and optional projects; invitations expire after 7 days and can be resent or revoked.
- [ ] Invitees can accept by signing in or creating an account.
- [ ] Admins can change a member's role or remove them; removed members lose access immediately.
- [ ] Removing a member keeps their existing reports unless an admin chooses to delete them.
- [ ] Seat counts update Stripe billing when members are added or removed.

**Technical Notes:** Enterprise administrators can manage people only within their own organization. Respect negotiated maximum user count.

**Priority:** Must-have
