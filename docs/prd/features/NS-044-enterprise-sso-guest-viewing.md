# NS-044: Enterprise SSO guest viewing

[Back to the PRD](../README.md)

**Requirement ID:** NS-044

**User Story:** As a stakeholder in an enterprise, I want to open a shared video link and sign in through my company's single sign-on, without needing a Naked Standup user account so that I can watch internal reports securely without being provisioned as a user.

**Acceptance Criteria:**

- [ ] An enterprise can set a share-link policy of Anyone in my organization, which requires a successful login through the enterprise identity provider.
- [ ] Anyone who authenticates through the enterprise's SSO (identified by the claimed domain or the identity provider configuration) can watch the report without a user account or seat being created.
- [ ] Guest viewers see only the report behind the link, with no access to feeds, other reports or AI features.
- [ ] The identity provider's subject and email are written to the audit log and view counts, with no persistent profile.
- [ ] Users who fail SSO or belong to another organization are denied.
- [ ] Guest playback is metered to the enterprise like other playback.

**Technical Notes:** Feasible with Keycloak identity brokering: authenticate against the organization's IdP and issue a short-lived, report-scoped viewer session that is not backed by a stored user. Needs a threat-model review and the audit/privacy handling described.

**Priority:** Should-have
