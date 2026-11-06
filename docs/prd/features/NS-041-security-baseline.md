# NS-041: Security baseline

[Back to the PRD](../README.md)

**Requirement ID:** NS-041

**User Story:** As a security officer, I want to have strong baseline security controls so that customer data is protected.

**Acceptance Criteria:**

- [ ] All traffic uses TLS 1.2 or newer, and data at rest is encrypted in Azure Blob Storage, databases and backups.
- [ ] Secrets are held in Azure Key Vault, and services use managed identities.
- [ ] No video can be fetched without a valid short-lived signed token or SAS URL.
- [ ] APIs have rate limiting, input validation and protection against common OWASP Top 10 issues.
- [ ] Dependencies and container images are scanned in the build pipeline, and critical findings block release.
- [ ] An independent penetration test is completed before general availability.

**Technical Notes:** Aim for controls that support later SOC 2 Type II. See Non-functional requirements.

**Priority:** Must-have
