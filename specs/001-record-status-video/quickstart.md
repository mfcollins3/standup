# Quickstart: Record Status Report Video

**Feature**: 001-record-status-video
**Date**: 2026-03-22

## Prerequisites

- macOS with Xcode 26+ installed
- [Tuist](https://tuist.io) installed (`curl -Ls https://install.tuist.io | bash`)
- Physical iOS device (camera/microphone required — Simulator does not support camera capture)
- Apple Developer account with signing team `WTG7RTG947`

## Setup

1. **Clone and switch to the feature branch**:

   ```bash
   git clone https://github.com/mfcollins3/standup.git
   cd standup
   git checkout 001-record-status-video
   ```

2. **Generate the Xcode workspace**:

   ```bash
   cd Apple
   tuist generate
   ```

3. **Open the workspace**:

   ```bash
   open Standup.xcworkspace
   ```

4. **Select a physical device** in Xcode's run destination picker (camera is not available in Simulator).

5. **Build and run** (⌘R).

## Architecture Overview

```
Sources/
├── StandupApp.swift              # App entry point
├── MainScene.swift               # Window group scene
├── MainView.swift                # Root view (navigates to recording)
└── Recording/                    # Feature module
    ├── RecordingScreen.swift     # Main recording UI: preview + timer + controls
    ├── ReviewScreen.swift        # Post-recording: playback + re-record
    ├── CameraPreview.swift       # UIViewRepresentable for AVCaptureVideoPreviewLayer
    ├── CountdownTimerView.swift  # Circular gauge with color-coded urgency
    ├── RecordingViewModel.swift  # @Observable state management
    ├── RecordingSession.swift    # AVCaptureSession lifecycle wrapper
    └── VideoPlayerView.swift     # AVKit VideoPlayer for local playback
```

### Data Flow

```
User Action → RecordingScreen → RecordingViewModel → RecordingSession (AVFoundation)
                                      ↓
                                 TimerState → CountdownTimerView
                                      ↓
                              RecordingState.finished → ReviewScreen → VideoPlayerView
```

## Key Concepts

### Recording Flow

1. User opens `RecordingScreen` — camera preview is live, timer shows 30s
2. User taps **Record** — `RecordingViewModel.startRecording()` starts capture + timer
3. Timer counts down: default color → yellow at 10s → red at 5s
4. Recording stops (auto at 0s or user taps **Stop**)
5. Navigation to `ReviewScreen` with the captured `.mov` file
6. User plays back video, then accepts or taps **Re-record** to loop back to step 1

### AVFoundation Session (RecordingSession)

- Manages `AVCaptureSession` on a dedicated serial `DispatchQueue`
- Inputs: front camera (`AVCaptureDeviceInput`) + microphone (`AVCaptureDeviceInput`)
- Output: `AVCaptureMovieFileOutput` writing to `tmp/{UUID}.mov`
- Delegate: `AVCaptureFileOutputRecordingDelegate` (NSObject subclass)

### Permissions

- Camera and microphone permissions checked on `RecordingScreen` appearance
- If `.notDetermined` → request via `AVCaptureDevice.requestAccess(for:)`
- If `.denied` / `.restricted` → show message with link to Settings
- Both must be `.authorized` before recording can start

### Timer Color States

| Remaining Time | Color | TimerUrgency |
|---|---|---|
| > 10 seconds | Default (system tint) | `.normal` |
| 5 < t ≤ 10 | Yellow | `.warning` |
| t ≤ 5 | Red | `.critical` |

## Running Tests

Tests are in the `StandupTests` target (to be added to Project.swift):

```bash
cd Apple
tuist generate
xcodebuild test -workspace Standup.xcworkspace -scheme StandupTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

### What's Testable

| Component | Testable? | How |
|---|---|---|
| `TimerState` / `TimerUrgency` | ✅ Yes | Pure value type — test urgency thresholds and progress calculations |
| `RecordingViewModel` state transitions | ✅ Yes | Inject a mock/protocol for `RecordingSession` to verify state changes |
| `CountdownTimerView` colors | ✅ Yes | Snapshot test or verify Color values from TimerUrgency |
| `RecordingSession` (AVFoundation) | ⚠️ Limited | Requires physical device; integration test only |
| `CameraPreview` | ⚠️ Limited | UIViewRepresentable — verify configuration, not rendering |

## Accessibility Checklist

- [ ] All recording controls have `.accessibilityLabel` and `.accessibilityHint`
- [ ] Timer announces state changes at 10s and 5s via `AccessibilityNotification.Announcement`
- [ ] Timer urgency is communicated via text label, not color alone
- [ ] All text supports Dynamic Type
- [ ] Contrast ratios meet WCAG 2.1 AA (4.5:1 minimum)

## Key Files to Modify

| File | Change |
|---|---|
| `Apple/Projects/Standup/Project.swift` | Add `StandupTests` target, add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to infoPlist |
| `Apple/Projects/Standup/Sources/MainView.swift` | Add navigation to `RecordingScreen` |
| New: `Sources/Recording/*.swift` | All recording feature source files |
| New: `Tests/Recording/*.swift` | Unit tests for view model and timer logic |
