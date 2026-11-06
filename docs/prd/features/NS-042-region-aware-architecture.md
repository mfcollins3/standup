# NS-042: Region-aware architecture

[Back to the PRD](../README.md)

**Requirement ID:** NS-042

**User Story:** As a platform owner, I want to have the service designed so it can be deployed to more regions so that I can add EU and Asia deployments without redesign.

**Acceptance Criteria:**

- [ ] Every workspace has a home region attribute, which is US in v1.0.0.
- [ ] Storage, database, search and queue resources are addressed through region-specific configuration, with no hard-coded region.
- [ ] Infrastructure is defined as code so a new region can be created from the same definition.
- [ ] Cross-region data transfer is documented, and personal data is not copied between regions without a recorded purpose.

**Technical Notes:** Architectural decision to be captured in an ADR. Cloudflare Stream data location needs review (Open Questions).

**Priority:** Should-have
