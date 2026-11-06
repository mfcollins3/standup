# NS-011: Record a status report on iOS

[Back to the PRD](../README.md)

**Requirement ID:** NS-011

**User Story:** As a team member, I want to record a status report on my iPhone or iPad so that I can post updates from anywhere.

**Acceptance Criteria:**

- [ ] Users record with the front or rear camera and microphone after granting permission.
- [ ] The same preview, timer, 5-minute limit and review/discard flow as the web app apply.
- [ ] Recording works on iPhone and iPad in supported orientations.
- [ ] Recording continues to be safe if the app is interrupted (call, backgrounding); partial recordings are recoverable or discarded with a message.
- [ ] Users can switch cameras before recording.

**Technical Notes:** Swift and SwiftUI with AVFoundation. Output H.264/AAC in MP4/MOV. Minimum version is iOS 27 (the latest).

**Priority:** Must-have
