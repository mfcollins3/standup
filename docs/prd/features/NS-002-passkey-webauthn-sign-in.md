# NS-002: Passkey (WebAuthn) sign-in

[Back to the PRD](../README.md)

**Requirement ID:** NS-002

**User Story:** As an individual user, I want to register and sign in with a passkey so that I can sign in securely without typing a password.

**Acceptance Criteria:**

- [ ] Signed-in users can register one or more passkeys and name or remove them.
- [ ] Users can sign in with a registered passkey on web, iOS and Android.
- [ ] A passkey sign-in satisfies multi-factor requirements without a separate TOTP prompt.
- [ ] Users keep at least one working sign-in method; removing the last one is blocked.

**Technical Notes:** Use Keycloak WebAuthn support. Mobile apps use platform passkey APIs through the system browser or the native credential manager. Associated domains and Digital Asset Links are required.

**Priority:** Must-have
