# NS-043: SCIM provisioning for enterprises

[Back to the PRD](../README.md)

**Requirement ID:** NS-043

**User Story:** As an enterprise administrator, I want to connect my identity provider through SCIM so that users and groups are created, updated and removed automatically.

**Acceptance Criteria:**

- [ ] Enterprise administrators can enable SCIM 2.0 and generate a credential (bearer token) for their identity provider.
- [ ] The service supports SCIM Users and Groups (create, read, update, patch, deactivate/delete, and filtering).
- [ ] Deactivating a user in the identity provider removes access, revokes sessions and frees the seat within 5 minutes.
- [ ] SCIM groups can be mapped to roles and projects.
- [ ] SCIM requests are rate limited and recorded in the audit log, and only affect the caller's organization.

**Technical Notes:** Implement a SCIM 2.0 endpoint (RFC 7643, RFC 7644) over Keycloak and the application database. Validate with Microsoft Entra ID and Okta.

**Priority:** Must-have
