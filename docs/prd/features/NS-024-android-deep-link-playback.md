# NS-024: Android deep-link playback

[Back to the PRD](../README.md)

**Requirement ID:** NS-024

**User Story:** As a stakeholder, I want to play a shared status report quickly on Android without installing the full app so that viewing a link is as easy as on iOS.

**Acceptance Criteria:**

- [ ] Opening a share link on Android opens the full app through verified App Links if it is installed.
- [ ] If the app is not installed, the link opens the web player, with a prompt to install the app.
- [ ] Tapping a push notification opens the report player directly.
- [ ] Google Play Instant / Instant Apps are not used.

**Technical Notes:** The closest Android alternative to an App Clip is verified App Links, notification deep links and the web player. Google Play Instant is deliberately excluded.

**Priority:** Should-have
