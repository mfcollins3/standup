# NS-036: Usage metering and overage billing

[Back to the PRD](../README.md)

**Requirement ID:** NS-036

**User Story:** As a billing owner, I want to be charged for the resources I consume so that pricing reflects my actual use.

**Acceptance Criteria:**

- [ ] Usage is metered per workspace for AI tokens, video storage, streaming delivery minutes, downloads, compute (transcoding) and other consumption costs.
- [ ] Usage events are reported to Stripe through meters and appear on the monthly invoice as separate line items.
- [ ] Metering is idempotent so a retried event is never billed twice.
- [ ] Usage per workspace and project is visible in the app within 1 hour of occurring.
- [ ] Each line item can be traced to its source events for a dispute.
- [ ] AI usage for transcription, summaries and embeddings is attributed to the user who recorded the report; conversation usage is attributed to the user who asked.

**Technical Notes:** Use Stripe usage-based billing (meters). Keep an internal usage ledger as the source of truth. Pricing rates are an open question.

**Priority:** Must-have
