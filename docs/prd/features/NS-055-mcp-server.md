# NS-055: MCP server

[Back to the PRD](../README.md)

**Requirement ID:** NS-055

**User Story:** As a developer, I want to connect my AI agents and applications to Naked Standup through a Model Context Protocol (MCP) server so that my agents can find, read and act on my standup data.

**Acceptance Criteria:**

- [ ] The service exposes a remote MCP server over HTTPS (Streamable HTTP) as part of the API.
- [ ] The server uses OAuth 2.0 authorization: it publishes protected resource metadata, accepts access tokens issued by Keycloak, and supports the authorization code flow for interactive clients and client credentials or token exchange (NS-056) for applications.
- [ ] Tools cover listing projects and reports, getting a report, transcript and summary, searching transcripts, asking a conversational question about a project (requires the conversation entitlement), and creating or revoking share links.
- [ ] Tools that change data or cost money require explicit scopes, are marked as such in their descriptions, and destructive tools (for example delete) are not exposed in v1.0.0.
- [ ] Transcripts, summaries and other content returned to agents are treated as untrusted data in the tool descriptions, and tool results never contain video tokens, secrets or other users' private data.
- [ ] Every tool call uses the caller's permissions, is rate limited (NS-048), metered, and written to the audit log.
- [ ] The tool list and schemas are published in the developer documentation.

**Technical Notes:** Official MCP SDK. Tool output is concise and paginated so that agents are not flooded with transcript text. Conversation tools use the same RAG pipeline as NS-030.

**Priority:** Must-have
