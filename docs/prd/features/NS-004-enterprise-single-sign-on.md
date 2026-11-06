# NS-004: Enterprise single sign-on

[Back to the PRD](../README.md)

**Requirement ID:** NS-004

**User Story:** As an enterprise administrator, I want to configure single sign-on with my company identity provider so that employees sign in with corporate credentials and my security policies apply.

**Acceptance Criteria:**

- [ ] Enterprise administrators can configure an OIDC or SAML 2.0 identity provider for their organization.
- [ ] Administrators can claim one or more email domains; users with those domains are routed to the organization's SSO.
- [ ] Users signing in through SSO are automatically added to the organization on first sign-in, with a configurable default role.
- [ ] Administrators can require SSO and disable password and social sign-in for the organization.
- [ ] SSO configuration errors are reported to the administrator with an actionable message and do not lock out the organization owner.

**Technical Notes:** Use Keycloak Organizations or one realm-level identity provider per organization. Domain verification by DNS TXT record. Enterprise SSO also supports guest viewing (NS-044) and SCIM (NS-043).

**Priority:** Must-have
