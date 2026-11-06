# NS-047: Enterprise email configuration

[Back to the PRD](../README.md)

**Requirement ID:** NS-047

**User Story:** As an enterprise administrator, I want to send my organization's emails through our own SMTP server or SendGrid account so that messages come from our domain and follow our policies.

**Acceptance Criteria:**

- [ ] Enterprise administrators can choose the platform default, a custom SMTP server, or their own SendGrid account (API key) for outgoing email.
- [ ] Credentials are stored encrypted in Azure Key Vault and never shown again after saving.
- [ ] Administrators can send a test email and see delivery errors.
- [ ] If the custom configuration fails, the system retries, notifies administrators, and does not fall back to another sender unless administrators allow it.
- [ ] Individuals and small teams use the platform's SendGrid account.

**Technical Notes:** Sender abstraction with SendGrid and SMTP providers. Validate SMTP hosts to prevent server-side request forgery.

**Priority:** Should-have
