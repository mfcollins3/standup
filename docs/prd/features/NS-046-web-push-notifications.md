# NS-046: Web push notifications

[Back to the PRD](../README.md)

**Requirement ID:** NS-046

**User Story:** As a stakeholder, I want to receive browser notifications when a teammate posts a report so that I get alerts without the mobile app.

**Acceptance Criteria:**

- [ ] Users can enable or disable web notifications from settings; the browser permission prompt appears only on user action.
- [ ] Notifications use the same project subscriptions and quiet hours as mobile push (NS-022).
- [ ] Clicking a notification opens the report in the web app.
- [ ] Notifications work in Chrome, Edge and Safari.

**Technical Notes:** Web Push API with VAPID and service workers. Safari uses its web push support.

**Priority:** Should-have
