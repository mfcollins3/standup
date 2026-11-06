# NS-025: Automatic transcription

[Back to the PRD](../README.md)

**Requirement ID:** NS-025

**User Story:** As a stakeholder, I want to get a transcript of every status report so that I can read or scan a report without watching it.

**Acceptance Criteria:**

- [ ] A transcript with timestamps is generated automatically after a video finishes processing.
- [ ] The transcript is shown beside the player and links to times in the video.
- [ ] Transcripts are available in 95% of cases within 5 minutes of the report becoming ready.
- [ ] The transcript can be used to produce captions for the player.
- [ ] Transcription failures are retried and shown as unavailable without blocking video playback.
- [ ] Transcription usage is metered for billing.

**Technical Notes:** Use speech-to-text models in Microsoft Foundry (for example Azure AI Speech or a Foundry-hosted transcription model). Audio is read from the original in Blob Storage. English in v1.0.0.

**Priority:** Must-have
