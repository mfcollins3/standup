# NS-050: Webhook notifications

[Back to the PRD](../README.md)

**Requirement ID:** NS-050

**User Story:** As a developer, I want to receive webhooks for important events so that my systems react when something happens.

**Acceptance Criteria:**

- [ ] Admins and developers can register HTTPS webhook endpoints per workspace and choose event types.
- [ ] Events include report.processing, report.ready, report.failed, report.deleted, transcript.ready, summary.ready, member.added, member.removed and share_link.created.
- [ ] Admins can see delivery history and resend an event.
- [ ] Endpoints that resolve to private or internal addresses are rejected.
- [ ] 99% of events are delivered within 1 minute of occurring.
- [ ] Each delivery is signed with HMAC-SHA256 using a per-endpoint secret, includes a unique event ID and timestamp, and receivers can reject deliveries older than 5 minutes; secrets can be rotated with an overlap period.
- [ ] A delivery times out after 10 seconds. A non-2xx response or timeout is retried up to 8 times with exponential backoff and jitter over about 24 hours.
- [ ] An endpoint that fails continuously for 3 days is disabled and the admins are notified.
- [ ] Delivery history is kept for 30 days.
- [ ] Each workspace can have up to 20 webhook endpoints.

**Technical Notes:** Use an outbox pattern and a queue. Webhook payloads carry IDs and metadata, not video URLs or tokens.

**Priority:** Must-have
