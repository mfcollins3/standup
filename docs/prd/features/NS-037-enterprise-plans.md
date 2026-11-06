# NS-037: Enterprise plans

[Back to the PRD](../README.md)

**Requirement ID:** NS-037

**User Story:** As an enterprise administrator, I want to have a negotiated plan with a fixed price, user cap and included services so that my contract matches my needs.

**Acceptance Criteria:**

- [ ] Platform staff can configure an enterprise plan with a fixed fee, a maximum user count and included usage allowances.
- [ ] Enterprise workspaces are invoiced per contract, including through Stripe invoicing with net terms.
- [ ] Usage beyond the included allowances is billed at the contract overage rates.
- [ ] Adding a user beyond the maximum is blocked with a message to contact sales.
- [ ] In v1.0.0, enterprise plans, trials and demos are provisioned manually by platform administrators working with sales; no self-service console is provided.

**Technical Notes:** Manual provisioning (Stripe dashboard and administrative scripts or database changes) is acceptable for v1.0.0. An internal console is out of scope.

**Priority:** Must-have
