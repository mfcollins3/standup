# NS-001: Email and password sign-up with TOTP

[Back to the PRD](../README.md)

**Requirement ID:** NS-001

**User Story:** As an individual user, I want to sign up and sign in with an email address, a password and a TOTP authenticator app so that my account is protected by multi-factor authentication.

**Acceptance Criteria:**

- [ ] Users can register with an email address and password; the email address must be verified before the account is usable.
- [ ] Passwords meet a documented strength policy and are checked against known-breached password lists.
- [ ] Users can enroll a TOTP authenticator app and are prompted for a code at sign-in once enrolled.
- [ ] Users receive one-time recovery codes when enrolling TOTP and can regenerate them.
- [ ] Repeated failed sign-in attempts trigger throttling or temporary lockout.

**Technical Notes:** Keycloak realm handles credentials and TOTP. Web and mobile apps use OIDC Authorization Code with PKCE; no custom credential handling in the apps.

**Priority:** Must-have
