# NS-010: Record a status report in the web app

[Back to the PRD](../README.md)

**Requirement ID:** NS-010

**User Story:** As a team member, I want to record a status report with my camera in the browser so that I can share my update without scheduling a meeting.

**Acceptance Criteria:**

- [x] Users choose a project and record using the camera and microphone after granting browser permission.
- [x] The app shows a live preview, elapsed time, a record/stop control and the remaining time.
- [x] Recording stops automatically at 5 minutes and tells the user.
- [ ] Users can review, discard and re-record before uploading.
- [x] Screen recording is not offered.
- [x] Clear messages are shown when permission is denied or no camera is available.

**Technical Notes:** Use getUserMedia and MediaRecorder with a feature check for Safari codec support (MP4/H.264 or WebM). Target 720p default; cap bitrate to control storage cost.

**Priority:** Must-have
