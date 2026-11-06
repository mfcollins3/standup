# NS-030: Conversational Q&A on a project or standup

[Back to the PRD](../README.md)

**Requirement ID:** NS-030

**User Story:** As a stakeholder, I want to chat with a project or a day's standup so that I can ask questions and get answers based on what the team said.

**Acceptance Criteria:**

- [ ] Users can open a chat scoped to a project, a date range or a single day's standup.
- [ ] Answers cite the reports and timestamps they are drawn from, linking to the video.
- [ ] The assistant only uses content the user has access to and says when it does not know.
- [ ] Conversations can be cleared and are not used for model training.
- [ ] Token usage is metered and attributed to the workspace.
- [ ] Workspace admins can turn the feature off.
- [ ] Only users with an AI-entitled seat can use conversations (NS-054).

**Technical Notes:** Retrieval-augmented generation over NS-029 chunks with access filters applied before retrieval. Uses Microsoft Foundry models. Included in v1.0.0. Requires a paid seat with AI entitlement (NS-054).

**Priority:** Should-have
