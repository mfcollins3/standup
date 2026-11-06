# NS-013: Offline recording and deferred upload

[Back to the PRD](../README.md)

**Requirement ID:** NS-013

**User Story:** As a team member, I want to record while offline and have the video upload later so that poor connectivity does not stop me from reporting.

**Acceptance Criteria:**

- [ ] Mobile apps allow recording with no network connection and save the video locally with project, author and timestamp.
- [ ] Pending reports appear in an Upload queue with status (waiting, uploading, failed, done).
- [ ] Uploads start automatically when connectivity returns and can be restricted to Wi-Fi in settings.
- [ ] Uploads resume after app restart and are retried with backoff.
- [ ] A local video is deleted only after the server confirms the upload.
- [ ] Users are notified (push and in-app) if a recording has not been uploaded 24 hours after it was recorded.

**Technical Notes:** Use background URLSession on iOS and WorkManager on Android. The web app is not required to support offline recording in v1.0.0. Limits on local storage are not part of v1.0.0 and will be addressed in a future release.

**Priority:** Must-have
