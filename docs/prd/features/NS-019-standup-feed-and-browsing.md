# NS-019: Standup feed and browsing

[Back to the PRD](../README.md)

**Requirement ID:** NS-019

**User Story:** As a stakeholder, I want to browse status reports by project, person and date so that I can see what each team has been doing.

**Acceptance Criteria:**

- [ ] Each project has a feed of reports in reverse chronological order, grouped by day.
- [ ] Users can filter by project, author and date range.
- [ ] The feed shows author, time (in the viewer's time zone), duration, thumbnail and summary when available.
- [ ] Viewers can mark reports as watched; unwatched reports are highlighted.
- [ ] The feed paginates and loads the first page within 2 seconds on broadband.

**Technical Notes:** Times stored in UTC and rendered in the viewer's time zone.

**Priority:** Must-have
