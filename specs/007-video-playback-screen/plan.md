# Implementation Plan: Video Playback Screen

**Branch**: `007-video-playback-screen` | **Date**: 2026-03-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/007-video-playback-screen/spec.md`

## Summary

Add a video playback screen to the Naked Standup iOS app that streams an HLS video from Cloudflare Stream. The main screen gets a second navigation link ("Play Status Report") alongside the existing recording link. A new dedicated `VideoPlaybackScreen` view uses AVKit's native `VideoPlayer` to play the hardcoded HLS `.m3u8` URL with built-in playback controls, error handling, and proper lifecycle cleanup. Dynamic video selection is deferred to a future story.

## Technical Context

**Language/Version**: Swift 6 / iOS 26.0+  
**Primary Dependencies**: SwiftUI, AVKit, Combine (all system frameworks)  
**Storage**: N/A (no persistence for this feature)  
**Testing**: Swift Testing (`import Testing`, `@Test` / `@Suite`)  
**Target Platform**: iOS/iPadOS 26.0+  
**Project Type**: mobile-app  
**Performance Goals**: Video playback begins within 3 seconds of screen appearing  
**Constraints**: Requires network connectivity for HLS streaming  
**Scale/Scope**: 1 new screen, 1 modified screen, 1 new source file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Pre-Design | Post-Design | Notes |
|-----------|-----------|-------------|-------|
| I. Ship Often | PASS | PASS | Smallest deliverable unit — 1 screen, 1 nav link, hardcoded URL |
| II. Keep Quality High | PASS | PASS | Tests planned for playback state transitions |
| III. Solicit and Respond to Feedback | N/A | N/A | No feedback mechanism needed for this increment |
| IV. Security by Default | PASS | PASS | Public HLS URL; no secrets; no auth required |
| V. Infrastructure as Code | N/A | N/A | No infrastructure changes |
| VI. Conventional Commits | PASS | PASS | Will follow conventional commit format |
| VII. Simplicity | PASS | PASS | 1 new file, 1 modified file; no abstractions; no new dependencies |
| VIII. Accessibility and Inclusivity | PASS | PASS | AVKit VideoPlayer provides built-in VoiceOver and Dynamic Type. Caption/subtitle tracks embedded in the HLS manifest are rendered automatically by AVKit VideoPlayer — no custom code required. |

All gates pass. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/007-video-playback-screen/
├── plan.md              # This file
├── research.md          # Phase 0: technology decisions
├── data-model.md        # Phase 1: entity definitions and state machine
├── quickstart.md        # Phase 1: implementation overview
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Apple/Projects/Standup/Sources/
├── MainView.swift                         # Modified: add "Play Status Report" NavigationLink
├── Recording/                             # Unchanged
│   ├── VideoPlayerView.swift              # Unchanged (used by recording review flow)
│   └── ...
├── Upload/                                # Unchanged
└── Playback/                              # New directory
    └── VideoPlaybackScreen.swift          # New: dedicated HLS playback screen
```

**Structure Decision**: The `Playback/` directory is placed alongside `Recording/` and `Upload/` as a peer feature module, following the existing pattern of organizing source by feature area. This keeps the playback feature isolated from the recording flow and allows independent evolution.

## Complexity Tracking

No Constitution Check violations. Table not applicable.
