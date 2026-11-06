# NS-026: AI summary for each report

[Back to the PRD](../README.md)

**Requirement ID:** NS-026

**User Story:** As a stakeholder, I want to see a short AI summary next to each video so that I can quickly learn what was said.

**Acceptance Criteria:**

- [ ] A summary is generated from the transcript and shown with the video in the feed and on the report page.
- [ ] The summary groups content as progress, plans and blockers where it can.
- [ ] Authors can edit or regenerate their summary.
- [ ] Summaries are labeled as AI generated.
- [ ] Token usage is metered and attributed to the workspace.
- [ ] Workspace admins can turn AI summaries off.

**Technical Notes:** Use models in Microsoft Foundry so data stays in the Azure tenant and is not used for model training. Store prompts and model versions for traceability.

**Priority:** Should-have
