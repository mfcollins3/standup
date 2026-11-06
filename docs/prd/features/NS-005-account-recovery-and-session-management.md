# NS-005: Account recovery and session management

[Back to the PRD](../README.md)

**Requirement ID:** NS-005

**User Story:** As an individual user, I want to recover my account and manage my signed-in sessions so that I can regain access and revoke lost devices.

**Acceptance Criteria:**

- [ ] Users can reset a forgotten password by email, with a time-limited single-use link.
- [ ] Users can view active sessions and devices and sign out any or all of them.
- [ ] Mobile apps keep users signed in with refresh tokens stored in the platform secure store.
- [ ] Changing a password or removing an authenticator revokes other sessions.
- [ ] Security-relevant events (password change, new passkey, MFA change) send a notification email.

**Technical Notes:** Keycloak session and token settings. Refresh tokens stored in iOS Keychain and Android Keystore-backed storage.

**Priority:** Must-have
