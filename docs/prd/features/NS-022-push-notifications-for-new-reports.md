# NS-022: Push notifications for new reports

[Back to the PRD](../README.md)

**Requirement ID:** NS-022

**User Story:** As a stakeholder, I want to receive a push notification when a teammate posts a report so that I can watch it promptly.

**Acceptance Criteria:**

- [ ] Users can opt in or out of push notifications globally and per project.
- [ ] A push notification is sent to subscribers of a project when a report becomes ready.
- [ ] Tapping a notification opens the report player directly.
- [ ] Notifications respect quiet hours the user configures.
- [ ] Invalid device tokens are removed automatically.
- [ ] Notifications are batched when many reports arrive in a short period.

**Technical Notes:** Send to APNs for iOS and FCM for Android directly (no intermediary). Web notifications are covered by NS-046.

**Priority:** Must-have
