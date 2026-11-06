# NS-034: Per-user subscription through Stripe

[Back to the PRD](../README.md)

**Requirement ID:** NS-034

**User Story:** As an individual user, I want to subscribe with a per-user monthly fee so that I can use the service on a plan that fits my team.

**Acceptance Criteria:**

- [ ] Customers can subscribe using Stripe Checkout and a payment method.
- [ ] The monthly fixed price is charged per user, and the quantity updates as members are added or removed, with proration.
- [ ] Customers can upgrade, downgrade or cancel in the Stripe Customer Portal.
- [ ] Subscription state is synchronized from Stripe webhooks, which are verified and idempotent.
- [ ] Card data never touches Naked Standup servers.

**Technical Notes:** Stripe Billing with subscription items. Taxes through Stripe Tax is an open question.

**Priority:** Must-have
