# NS-018: On-demand video playback

[Back to the PRD](../README.md)

**Requirement ID:** NS-018

**User Story:** As a stakeholder, I want to watch status reports on demand on the web, iOS and Android so that I can catch up when it suits me.

**Acceptance Criteria:**

- [ ] Authorized users can play any ready report they have access to using adaptive streaming.
- [ ] The player supports play/pause, seek, replay, playback speed (0.5x to 2x), full screen and volume.
- [ ] Captions generated from the transcript are available when the transcript is ready.
- [ ] Playback resumes from where the viewer stopped on the same report.
- [ ] Viewers without access get a clear no-access screen and no video data.

**Technical Notes:** Cloudflare Stream player or HLS/DASH with signed tokens minted by the API per request. Use AVPlayer on iOS and Media3 on Android.

**Priority:** Must-have
