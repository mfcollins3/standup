# NS-027: Combined summary email

[Back to the PRD](../README.md)

**Requirement ID:** NS-027

**User Story:** As a stakeholder, I want to receive one email with the summaries of everyone on the team so that I can stay informed without opening each video.

**Acceptance Criteria:**

- [ ] Users can subscribe to a daily or weekly digest per project and choose the send time and time zone.
- [ ] The email combines summaries by team member, each with a link to its video.
- [ ] The digest skips members who posted nothing and notes who did not report.
- [ ] Each email has an unsubscribe link and honors preferences.
- [ ] Emails link to a signed-in view; they never embed video tokens that bypass access checks.
- [ ] Individuals and small teams receive email through the platform's SendGrid account; enterprises can use their own sender settings (NS-047).

**Technical Notes:** Platform email uses SendGrid. Scheduling by time zone.

**Priority:** Should-have
