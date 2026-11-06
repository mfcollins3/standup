# NS-048: Public REST API

[Back to the PRD](../README.md)

**Requirement ID:** NS-048

**User Story:** As a developer, I want to use a documented REST API to access my data and perform operations so that I can build my own tools and integrations.

**Acceptance Criteria:**

- [ ] The REST API is versioned (for example /v1), uses JSON, standard HTTP verbs and status codes, and returns consistent error objects.
- [ ] The API covers workspaces, projects, members, reports (list, get, create upload, delete), transcripts, summaries, share links, retention settings and usage data, subject to the caller's permissions.
- [ ] List endpoints support cursor pagination, filtering and sorting.
- [ ] Create operations support idempotency keys.
- [ ] Default rate limits are 600 read requests and 120 write requests per minute per client, 3,000 requests per minute per workspace, and 60 upload requests per minute per user, with higher limits available by contract; exceeded limits return 429 with a Retry-After header.
- [ ] Default page size is 50, maximum 200. Idempotency keys are honored for 24 hours.
- [ ] Limits are returned in response headers.
- [ ] An OpenAPI 3.1 specification is published and kept in sync with the implementation.
- [ ] The API calls use the same authorization checks as the apps.

**Technical Notes:** The apps themselves should use the same REST API where practical. Use token-bucket limiting at the gateway (for example Azure API Management or the application). GraphQL and SDKs are out of scope for v1.0.0.

**Priority:** Must-have
