# NS-009: Enterprise organization administration

[Back to the PRD](../README.md)

**Requirement ID:** NS-009

**User Story:** As an enterprise administrator, I want to manage all users, groups and settings for my enterprise so that I can govern use of the product across the company.

**Acceptance Criteria:**

- [ ] Enterprise administrators see a directory of all organization users with role, status and last activity.
- [ ] Administrators can create groups of users and assign a group to projects.
- [ ] Administrators can suspend and reactivate users.
- [ ] Organization-wide settings (retention, sharing policy, SSO enforcement) are managed in one place.
- [ ] Administrator actions are written to the audit log.

**Technical Notes:** Builds on NS-004, NS-007 and NS-031. Groups are Keycloak groups.

**Priority:** Must-have
