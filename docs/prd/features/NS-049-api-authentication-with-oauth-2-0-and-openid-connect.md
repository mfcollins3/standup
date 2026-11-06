# NS-049: API authentication with OAuth 2.0 and OpenID Connect

[Back to the PRD](../README.md)

**Requirement ID:** NS-049

**User Story:** As a developer, I want to authenticate with OAuth 2.0 and OpenID Connect so that my applications access the API securely.

**Acceptance Criteria:**

- [ ] The API accepts OAuth 2.0 access tokens issued by Keycloak.
- [ ] The Authorization Code flow (with PKCE) is supported for applications acting for a user.
- [ ] The Client Credentials flow is supported for server-to-server applications, acting as a workspace-scoped service principal.
- [ ] Developers can register, rotate and delete OAuth clients and manage their scopes in the web app; only admins can create client-credentials clients.
- [ ] Scopes limit access (for example reports:read, reports:write, members:read, webhooks:manage).
- [ ] Tokens are short-lived, and revoking a client or user stops access within 5 minutes.
- [ ] OpenID Connect discovery documents are published.
- [ ] Applications can exchange an enterprise SSO token for an API token using OAuth 2.0 token exchange (NS-056).

**Technical Notes:** Keycloak clients and scopes with per-workspace service accounts. Basic authentication and static API keys are not supported.

**Priority:** Must-have
