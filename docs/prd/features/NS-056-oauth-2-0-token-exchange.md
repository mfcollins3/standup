# NS-056: OAuth 2.0 token exchange

[Back to the PRD](../README.md)

**Requirement ID:** NS-056

**User Story:** As a developer, I want to exchange an SSO token for a Naked Standup access token using OAuth 2.0 token exchange (RFC 8693) so that my applications can call the API and MCP server on behalf of users who signed in through our company SSO.

**Acceptance Criteria:**

- [ ] The token endpoint supports grant_type urn:ietf:params:oauth:grant-type:token-exchange.
- [ ] A registered client can submit a subject_token of one of these types: an OpenID Connect ID token (urn:ietf:params:oauth:token-type:id_token), a SAML 2.0 assertion (urn:ietf:params:oauth:token-type:saml2), or a JWT access token (urn:ietf:params:oauth:token-type:access_token).
- [ ] ID tokens are accepted only when they were issued by the organization's configured identity provider for the Naked Standup client, with a valid signature, issuer, audience, expiry and, where supplied, nonce.
- [ ] SAML assertions are accepted only when signed by the configured identity provider, within their validity window, restricted to the Naked Standup audience, and not replayed (each assertion ID is accepted once).
- [ ] JWT access tokens are accepted only when the identity provider issued them for a Naked Standup audience or scope; access tokens meant for other resources (for example Microsoft Graph), opaque access tokens and refresh tokens are rejected.
- [ ] Users who are not members of the organization, and unknown issuers, are rejected with an OAuth error and no detail that helps attackers.
- [ ] The requested audience or resource (the REST API or the MCP server) and scope are honored, and the issued token is never broader than the client's registered scopes or the user's permissions.
- [ ] The issued access token is short-lived (15 minutes or less) and no refresh token is returned.
- [ ] Delegation to a service or application is expressed with the actor_token or the act claim so that audit logs show the user and the application.
- [ ] Only clients that an admin has allowed to use token exchange can call it.
- [ ] Exchange attempts, successes and failures are recorded in the audit log.

**Technical Notes:** Keycloak standard token exchange with the enterprise identity provider as a trusted external issuer. Keycloak's support for external SAML and JWT access-token subject tokens must be verified early; custom validation may be needed. The RFC number is 8693 (the link given is correct; 8963 is a different number).

**Priority:** Must-have
