# NS-007: Roles and permissions

[Back to the PRD](../README.md)

**Requirement ID:** NS-007

**User Story:** As a workspace administrator, I want to assign roles to people so that each person can do only what they need.

**Acceptance Criteria:**

- [ ] Roles are Owner, Admin, Member (record and view) and Viewer (view only).
- [ ] Roles can be assigned at workspace level and overridden per project.
- [ ] Only Owners and Admins can manage members, billing, retention and sharing settings.
- [ ] Authorization is enforced server-side on every API call and playback token request.
- [ ] Viewers cannot record or upload; the UI hides these actions and the API rejects them.
- [ ] Viewers do not need a paid seat for on-demand playback of videos.
- [ ] Viewers need a paid seat to use AI features such as conversational Q&A (NS-030); without one the feature is shown as unavailable with an upgrade prompt.

**Technical Notes:** Role checks live in the API; Keycloak holds identity and organization membership. Seat entitlement is evaluated per feature (see NS-054).

**Priority:** Must-have
