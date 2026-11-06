# NS-003: Google, Microsoft and Apple sign-in

[Back to the PRD](../README.md)

**Requirement ID:** NS-003

**User Story:** As an individual user, I want to sign in with my Google, Microsoft or Apple account so that I do not need another password.

**Acceptance Criteria:**

- [ ] Sign-in and sign-up offer Google, Microsoft and Apple as identity providers on web, iOS and Android.
- [ ] A first social sign-in creates an account; later sign-ins with the same verified email link to the same account.
- [ ] Users can link and unlink social identities from account settings, but not the last remaining sign-in method.
- [ ] Sign in with Apple is offered in the iOS app, as App Store rules require when other social sign-in is offered.
- [ ] Apple private relay email addresses are handled.

**Technical Notes:** Configure each provider as a Keycloak identity provider. Define the account-linking rule for matching verified emails.

**Priority:** Must-have
