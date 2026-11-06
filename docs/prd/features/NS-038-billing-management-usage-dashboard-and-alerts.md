# NS-038: Billing management, usage dashboard and alerts

[Back to the PRD](../README.md)

**Requirement ID:** NS-038

**User Story:** As a billing owner, I want to see invoices, current usage and get alerts so that there are no surprises on my bill.

**Acceptance Criteria:**

- [ ] Billing owners can view and download invoices and update payment methods.
- [ ] A usage dashboard shows current-period usage and the estimated cost by category.
- [ ] Owners can set a spending alert threshold and optionally a hard cap.
- [ ] Failed payments trigger email notifications and a grace period before access is restricted.
- [ ] Only Owners and designated billing contacts can see billing data.

**Technical Notes:** Dunning through Stripe Smart Retries and custom emails.

**Priority:** Should-have
