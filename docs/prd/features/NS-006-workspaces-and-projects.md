# NS-006: Workspaces and projects

[Back to the PRD](../README.md)

**Requirement ID:** NS-006

**User Story:** As a team lead, I want to create a workspace and projects for my team so that status reports are organized by the work they relate to.

**Acceptance Criteria:**

- [ ] Every account has a workspace; individuals get a personal workspace automatically.
- [ ] Workspace admins can create, rename, archive and delete projects.
- [ ] Each project has its own standup feed of status reports.
- [ ] A status report belongs to exactly one project.
- [ ] Users can belong to multiple workspaces and switch between them.

**Technical Notes:** Data model: Workspace (or enterprise Organization) contains Projects; Projects contain Reports. Projects are enough for v1.0.0; there is no separate Teams layer.

**Priority:** Must-have
