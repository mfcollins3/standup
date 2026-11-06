# NS-040: Privacy rights: export and deletion

[Back to the PRD](../README.md)

**Requirement ID:** NS-040

**User Story:** As an individual user, I want to export or delete my personal data so that my privacy rights are respected.

**Acceptance Criteria:**

- [ ] Users can request an export of their account data, reports and transcripts, and receive it within 30 days (target 7 days).
- [ ] Users can delete their account, which deletes their reports, transcripts, vectors and personal data in all stores, subject to legal retention.
- [ ] Enterprise administrators can submit requests for users in their organization.
- [ ] Request handling is logged.
- [ ] Privacy policy and data processing terms are shown at sign-up and accepted.
- [ ] Sign-up requires users to confirm that they are at least 13 years old; accounts found to belong to younger children are closed and their data is deleted.

**Technical Notes:** Supports GDPR and CCPA/CPRA even before European deployment. Stripe and Cloudflare are sub-processors that must be listed.

**Priority:** Must-have
