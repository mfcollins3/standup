# Research: Video Playback Screen

**Feature**: 007-video-playback-screen  
**Date**: 2026-03-27

## R-001: HLS Streaming Support in AVKit

**Decision**: Use `AVPlayer(url:)` with the Cloudflare Stream HLS `.m3u8` URL directly.

**Rationale**: AVKit's `VideoPlayer` (SwiftUI) natively supports HLS `.m3u8` URLs without any additional libraries or custom HTTP client. `AVPlayer` handles manifest parsing, adaptive bitrate quality selection, and segment fetching automatically. This is the simplest possible approach and aligns with Constitution Principle VII (Simplicity).

**Alternatives Considered**:
- **Third-party player SDK (e.g., Cloudflare Stream SDK)**: Rejected — adds unnecessary dependency; AVPlayer already handles HLS natively.
- **Custom HTTP-based streaming implementation**: Rejected — over-engineering; AVPlayer handles all HLS complexity.
- **AVPlayerViewController instead of SwiftUI VideoPlayer**: Rejected — less SwiftUI-native; `VideoPlayer` wraps `AVPlayerViewController` internally and integrates better with the SwiftUI view hierarchy.

## R-002: Error Observation Pattern

**Decision**: Observe `AVPlayerItem.status` using Combine's `publisher(for: \.status)` to detect playback failures and display user-facing error messages.

**Rationale**: Combine publishers integrate cleanly with SwiftUI's reactive model. When `AVPlayerItem.status` transitions to `.failed`, the `AVPlayerItem.error` property contains the underlying `NSError` describing the failure. This covers network errors, unsupported formats, and server-side issues.

**Alternatives Considered**:
- **NotificationCenter (`failedToPlayToEndTimeNotification`)**: Rejected — only fires when playback is already in progress and then fails mid-stream; does not catch initial load failures.
- **KVO with `NSKeyValueObservation`**: Viable but less idiomatic in SwiftUI compared to Combine publishers.
- **Async/await observation**: Not directly supported for AVPlayerItem status changes.

## R-003: New View vs Reusing Existing VideoPlayerView

**Decision**: Create a new dedicated `VideoPlaybackScreen` view for the playback feature. The existing `VideoPlayerView` in `Sources/Recording/` will remain unchanged.

**Rationale**: The existing `VideoPlayerView` is a minimal wrapper designed for local file playback in the recording review flow. It lacks error handling, loading state display, and `onDisappear` cleanup — all of which are required for the playback screen (FR-005, FR-006). Modifying it would couple the recording and playback features, violating separation of concerns. The cost of a new view is low (small file), and it preserves the independence of both features.

**Alternatives Considered**:
- **Extend existing `VideoPlayerView` with optional error/loading/cleanup**: Rejected — would couple recording review and playback features; risks breaking the existing recording flow.
- **Extract shared video player component used by both flows**: Rejected — premature abstraction per Constitution Principle VII (Simplicity/YAGNI). Can be reconsidered if a third video playback context arises.

## R-004: AVPlayer Lifecycle and Cleanup

**Decision**: Use `.onDisappear` to pause the player and release resources when the user navigates away from the playback screen.

**Rationale**: `.onDisappear` is called by SwiftUI when the view is removed from the hierarchy (back navigation, dismiss). Calling `player?.pause()` and setting `player = nil` ensures playback stops immediately and the AVPlayer's internal resources are deallocated. This satisfies FR-005. The system automatically handles app backgrounding and device lock scenarios.

**Alternatives Considered**:
- **Relying on ARC deallocation only**: Rejected — a retained @State reference can delay deallocation, causing audio to continue briefly after navigation.
- **Using `scenePhase` observation**: Not needed for basic cleanup; `.onDisappear` covers all navigation-away scenarios.

## R-005: Pre-defined Video URL

**Decision**: Use the Cloudflare Stream HLS URL `https://customer-j8jlsnmsytg4ne2z.cloudflarestream.com/2916cde874951283bc3cc8b7f3f9a9ba/manifest/video.m3u8` as the hardcoded video source.

**Rationale**: The user explicitly provided this URL. It is a publicly accessible HLS stream from Cloudflare Stream, compatible with AVPlayer. This satisfies the spec's assumption that the pre-defined URL points to a publicly accessible remote video. Real navigation from a dynamic list of videos will be implemented in a subsequent story.

**Alternatives Considered**: None — the URL was provided as a direct requirement.
