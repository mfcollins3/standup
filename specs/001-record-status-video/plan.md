# Implementation Plan: Record Status Report Video

**Branch**: `001-record-status-video` | **Date**: 2026-03-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-record-status-video/spec.md`

## Summary

Enable users to record a 30-second status report video on iPhone and iPad using the device camera and microphone. The implementation uses SwiftUI for the user interface and AVFoundation for video capture. The feature includes a live camera preview, a color-coded countdown timer (default → yellow at 10s → red at 5s), automatic stop at 30 seconds, early stop capability, and a review screen with playback and re-record options. All video processing is local to the device; submission is out of scope.

## Technical Context

**Language/Version**: Swift 6.2  
**Primary Dependencies**: SwiftUI (UI framework), AVFoundation (video capture and playback)  
**Storage**: Local temporary files in the app's `tmp/` directory (recorded video segments)  
**Testing**: Swift Testing (`import Testing`) + XCTest via Tuist `.unitTests` target (new `StandupTests` target to be added to Project.swift)  
**Target Platform**: iOS/iPadOS 26.0+ (iPhone and iPad)  
**Project Type**: mobile-app  
**Performance Goals**: 60 fps camera preview, timer updates every 1 second, color transitions within 0.5s of thresholds  
**Constraints**: 30-second max recording duration, offline-capable (no network required), must handle app interruptions gracefully  
**Scale/Scope**: Single feature addition to existing app; ~3 screens (recording, review/playback), ~8-10 new source files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Ship Often | ✅ PASS | Feature is scoped to recording only; video submission is explicitly a separate feature. The recording flow is independently shippable. |
| II | Keep Quality High | ✅ PASS | Test target designed (`StandupTests` with `product: .unitTests`). Testability strategy documented in quickstart.md. `TimerState`, `RecordingViewModel` state transitions, and urgency thresholds are all unit-testable. ADR for AVFoundation architecture to be written during implementation. |
| III | Solicit and Respond to Feedback | ✅ PASS | N/A for implementation plan phase. Feedback mechanisms can be added post-ship. |
| IV | Security by Default | ✅ PASS | Camera and microphone permissions follow platform-standard authorization flow. Video files are stored locally in app sandbox. No secrets or network calls involved. |
| V | Infrastructure as Code | ✅ PASS | N/A — this feature is entirely client-side with no Azure resource changes. |
| VI | Conventional Commits | ✅ PASS | All commits will follow the conventional format defined in copilot-instructions.md. |
| VII | Simplicity | ✅ PASS | Uses AVFoundation directly without unnecessary abstractions. SwiftUI views compose the UI. No over-engineering. |
| VIII | Accessibility and Inclusivity | ✅ PASS | Accessibility design documented: VoiceOver labels on all controls, `AccessibilityNotification.Announcement` at 10s/5s marks, text labels alongside color for urgency (not color-only), Dynamic Type support, WCAG 2.1 AA contrast ratios. Checklist in quickstart.md. |

**Gate Result**: PASS. All 8 principles satisfied. Principles II and VIII addressed in Phase 1 design (test target in data-model/quickstart, accessibility in research.md §8 and quickstart.md checklist).

## Project Structure

### Documentation (this feature)

```text
specs/001-record-status-video/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A — no external API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository)

```text
Apple/Projects/Standup/
├── Sources/
│   ├── StandupApp.swift              # Existing app entry point
│   ├── MainScene.swift               # Existing main scene
│   ├── MainView.swift                # Existing main view (will navigate to recording)
│   └── Recording/                    # New feature module
│       ├── RecordingScreen.swift     # SwiftUI view: camera preview + timer + record/stop
│       ├── ReviewScreen.swift        # SwiftUI view: playback + re-record
│       ├── CameraPreview.swift       # UIViewRepresentable wrapping AVCaptureVideoPreviewLayer
│       ├── CountdownTimerView.swift  # SwiftUI view: circular progress gauge with color states
│       ├── RecordingViewModel.swift  # ObservableObject managing capture session state
│       ├── RecordingSession.swift    # Model: encapsulates AVCaptureSession lifecycle
│       └── VideoPlayerView.swift     # SwiftUI view wrapping AVPlayer for playback
├── Resources/
│   └── (existing assets)
└── Config/
    └── (existing xcconfig files)

Apple/Projects/Standup/Tests/         # Test sources for StandupTests target
└── Recording/
    ├── RecordingViewModelTests.swift
    └── CountdownTimerTests.swift
```

**Structure Decision**: Feature code is organized in a `Recording/` subdirectory under the existing `Sources/` folder, following a feature-based grouping convention. A `StandupTests` test target is defined in Project.swift via Tuist with sources in `Tests/` under the `Standup` project directory, enabling TDD per Constitution Principle II.

## Complexity Tracking

> No constitution violations requiring justification. Actions for Principles II and VIII are additive (adding tests and accessibility support), not violations.
