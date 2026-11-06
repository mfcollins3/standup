# NS-054: Conversation entitlement

[Back to the PRD](../README.md)

**Requirement ID:** NS-054

**User Story:** As a workspace administrator, I want to control which people can use AI conversations so that the most expensive AI feature is limited to paid seats.

**Acceptance Criteria:**

- [ ] Only conversational Q&A (NS-030) requires an AI entitlement, which requires a paid seat; Members and Viewers can be given or denied it by admins.
- [ ] The entitlement is checked on every conversation request.
- [ ] Viewers without the entitlement can still play videos and read transcripts, summaries and search results.
- [ ] Transcription, summaries, embeddings and indexing are not seat-gated; their cost is attributed to the user who recorded the report.
- [ ] Admins see which users hold the entitlement and the conversation usage per user.
- [ ] Changing entitlement updates Stripe quantities and prorates.

**Technical Notes:** Entitlement checks live in the API, not the client.

**Priority:** Must-have
