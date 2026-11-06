# NS-053: Overdue upload notification

[Back to the PRD](../README.md)

**Requirement ID:** NS-053

**User Story:** As a team member, I want to be told if a recording could not be uploaded after 24 hours so that I can fix the problem before the report is lost or stale.

**Acceptance Criteria:**

- [ ] If a recording is still not uploaded 24 hours after it was recorded, the user receives a push notification and an in-app banner.
- [ ] The notification opens the upload queue with the failed item and its reason.
- [ ] Notifications repeat at most once every 24 hours until the upload is done or discarded.
- [ ] No notification is sent once the server confirms the upload.

**Technical Notes:** Local scheduled notification so it works with no connectivity, in addition to a server notification where the device has already registered the recording.

**Priority:** Must-have
