# NS-012: Record a status report on Android

[Back to the PRD](../README.md)

**Requirement ID:** NS-012

**User Story:** As a team member, I want to record a status report on my Android phone or tablet so that I can post updates from anywhere.

**Acceptance Criteria:**

- [ ] Users record with the front or rear camera and microphone after granting permission.
- [ ] The same preview, timer, 5-minute limit and review/discard flow as the web app apply.
- [ ] Interruptions (call, backgrounding) are handled without losing or corrupting the recording.
- [ ] Users can switch cameras before recording.

**Technical Notes:** Kotlin and Jetpack Compose with CameraX. Output H.264/AAC in MP4. Minimum Android version is an open question (proposed Android 10, API 29).

**Priority:** Must-have
