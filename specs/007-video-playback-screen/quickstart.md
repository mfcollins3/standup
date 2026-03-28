# Quickstart: Video Playback Screen

**Feature**: 007-video-playback-screen  
**Date**: 2026-03-27

## Overview

This feature adds a video playback screen to the Naked Standup iOS app. Users navigate from the main screen to a dedicated player that streams an HLS video from Cloudflare Stream. The feature uses a hardcoded video URL as a placeholder until dynamic video selection is implemented in a future story.

## What Gets Built

1. **New navigation link on MainView**: A second `NavigationLink` labeled "Play Status Report" is added to the existing list on the main screen.
2. **New `Playback/` directory**: A new source directory alongside `Recording/` and `Upload/` to house playback-related views.
3. **New `VideoPlaybackScreen` view**: A dedicated SwiftUI view that:
   - Loads and plays an HLS video stream using `AVKit.VideoPlayer`
   - Shows a loading indicator while the video buffers
   - Displays an error message if the video fails to load
   - Stops playback and cleans up resources when the user navigates back

## Architecture

```
Sources/
├── MainView.swift              # Modified: add "Play Status Report" link
├── Recording/                  # Unchanged
├── Upload/                     # Unchanged
└── Playback/
    └── VideoPlaybackScreen.swift  # New: dedicated playback screen
```

## Key Technical Decisions

| Decision | Choice | Reference |
|----------|--------|-----------|
| HLS streaming | Native `AVPlayer` with `.m3u8` URL | [research.md R-001](research.md) |
| Error observation | Combine `publisher(for: \.status)` on `AVPlayerItem` | [research.md R-002](research.md) |
| New view vs reuse | New `VideoPlaybackScreen`; existing `VideoPlayerView` unchanged | [research.md R-003](research.md) |
| Cleanup on navigation | `.onDisappear` pauses player and releases resources | [research.md R-004](research.md) |
| Video URL | Hardcoded Cloudflare Stream HLS URL | [research.md R-005](research.md) |

## Constitution Alignment

- **Simplicity (VII)**: One new file, one modified file. No abstractions, no new dependencies.
- **Quality (II)**: Unit tests for the playback view model / state transitions.
- **Accessibility (VIII)**: AVKit `VideoPlayer` provides built-in VoiceOver and Dynamic Type support.
- **Ship Often (I)**: Hardcoded URL keeps scope minimal; dynamic navigation deferred to next story.
