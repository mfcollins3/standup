# NS-039: Audit log

[Back to the PRD](../README.md)

**Requirement ID:** NS-039

**User Story:** As an enterprise administrator, I want to see a log of sensitive actions so that I can investigate and demonstrate compliance.

**Acceptance Criteria:**

- [ ] Sign-ins, role changes, member changes, share-link creation and revocation, downloads, deletions and setting changes are recorded with actor, time, IP address and target.
- [ ] Admins can view and filter the log and export it as CSV.
- [ ] Audit records cannot be edited or deleted by customers and are kept for at least 1 year.
- [ ] Audit data is available only to Owners and Admins.

**Technical Notes:** Write-once storage or append-only table. Consider export to a customer SIEM later.

**Priority:** Should-have
