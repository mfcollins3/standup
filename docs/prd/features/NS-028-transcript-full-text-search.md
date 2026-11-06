# NS-028: Transcript full-text search

[Back to the PRD](../README.md)

**Requirement ID:** NS-028

**User Story:** As a stakeholder, I want to search transcripts by keyword so that I can find when something was discussed.

**Acceptance Criteria:**

- [ ] Users can search across transcripts for the projects they can access.
- [ ] Results show the matching snippet, author, date, and a link to the timestamp in the video.
- [ ] Search supports filters by project, author and date range.
- [ ] Search results never include reports the user cannot access.
- [ ] Results return in under 2 seconds for the 95th percentile.

**Technical Notes:** Index transcripts in Azure AI Search (full-text and hybrid). Enforce access filtering in every query.

**Priority:** Should-have
