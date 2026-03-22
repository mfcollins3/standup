# Research: Record Status Report Video

**Date**: 2026-03-22
**Feature**: 001-record-status-video

## 1. AVFoundation Video Capture Architecture

**Decision**: Use `AVCaptureSession` with `AVCaptureMovieFileOutput` for video+audio recording to `.mov` files.

**Rationale**: `AVCaptureMovieFileOutput` is the standard AVFoundation API for recording video with audio to a file. It handles muxing, compression, and file writing automatically, avoiding the complexity of `AVAssetWriter` which is unnecessary for this use case. The session-based architecture (`AVCaptureSession` → inputs + outputs) is well-documented and the recommended approach for iOS.

**Alternatives considered**:
- `AVAssetWriter`: More control over encoding, but significantly more complex. Not needed for a simple 30-second recording.
- `ReplayKit`: Designed for screen recording, not camera capture. Not appropriate.

**Key implementation details**:
- Use `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)` for front camera
- Use `AVCaptureDevice.default(for: .audio)` for microphone
- Use `sessionPreset = .high` for good quality short-form video
- `startRunning()` and `stopRunning()` block — must run on a dedicated serial `DispatchQueue`
- Recording delegate class must inherit `NSObject` (required by `NSObjectProtocol`)
- `fileOutput(_:didFinishRecordingTo:from:error:)` is the required delegate method for completion

## 2. SwiftUI + AVFoundation Integration (Camera Preview)

**Decision**: Use `UIViewRepresentable` wrapping a custom `UIView` subclass with `layerClass` override returning `AVCaptureVideoPreviewLayer`.

**Rationale**: There is no native SwiftUI view for live camera preview. The `layerClass` override pattern (from Apple's AVCam sample) is more efficient than manually adding a sublayer because it avoids layout issues. `UIViewRepresentable` is the standard bridge from UIKit to SwiftUI.

**Alternatives considered**:
- `UIViewControllerRepresentable`: Adds unnecessary view controller overhead for a simple layer display.
- Manual sublayer management: Requires additional layout code and is more error-prone.

**Key implementation details**:
- `PreviewView: UIView` with `override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }`
- Set `videoGravity = .resizeAspectFill` for full-bleed preview
- Connect via `previewLayer.session = captureSession`

## 3. SwiftUI Video Playback

**Decision**: Use SwiftUI's `VideoPlayer` from `AVKit` with `AVPlayer(url:)` for local file playback.

**Rationale**: `VideoPlayer` provides built-in transport controls (play, pause, scrubber) and is the standard SwiftUI approach. It handles `@MainActor` requirements automatically and supports local file URLs directly.

**Alternatives considered**:
- `AVPlayerLayer` wrapped in `UIViewRepresentable`: Only needed if custom transport controls are required. The built-in controls are sufficient for the review screen.

**Key implementation details**:
- Create `AVPlayer(url: localFileURL)` with the `.mov` file from recording
- Initialize player in `.task` modifier (Apple's recommended pattern)
- `VideoPlayer` is `@MainActor @preconcurrency` — standard SwiftUI usage

## 4. Camera & Microphone Permissions

**Decision**: Use `AVCaptureDevice.authorizationStatus(for:)` and `requestAccess(for:)` to check and request permissions before configuring the capture session. Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to Info.plist via Tuist.

**Rationale**: Both permissions are required for video+audio recording. The async version of `requestAccess` is compatible with Swift 6.2 strict concurrency. Permissions must be checked before session setup because the system sends black frames / silent audio if not yet authorized.

**Alternatives considered**: None — this is the only supported approach on iOS.

**Key implementation details**:
- Add to `infoPlist` in Project.swift: `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`
- Check status before configuring session; request if `.notDetermined`
- If `.denied` or `.restricted`, show UI directing user to Settings
- Both `.video` and `.audio` must be requested separately

## 5. Test Target Setup with Tuist

**Decision**: Add a new `StandupTests` target to Project.swift using `product: .unitTests` with a dependency on the `Standup` app target. Use Swift Testing (`import Testing`) as the primary test framework.

**Rationale**: Constitution Principle II mandates TDD. The project currently has no test target. Tuist's `.unitTests` product type automatically configures XCTest hosting. Swift Testing is the modern framework for Swift 6.2 and can coexist with XCTest in the same target.

**Alternatives considered**:
- XCTest only: Still supported but Swift Testing is the modern approach for new code on Swift 6.2.
- Separate test project: Unnecessary complexity; a target within the same project is simpler and follows Tuist conventions.

**Key implementation details**:
- New function `standupTests()` in Project.swift returning `.target(name: "StandupTests", product: .unitTests, ...)`
- Sources at `Apple/Projects/Standup/Tests/**`
- Dependencies: `[.target(name: "Standup")]`
- Add to `targets` array alongside `standupApp()`

## 6. Temporary Video File Storage

**Decision**: Use `FileManager.default.temporaryDirectory` with UUID-based filenames and `.mov` extension.

**Rationale**: The temporary directory is automatically managed by iOS (can be purged when app is not running) and is not backed up. This aligns with the feature scope: recordings are ephemeral until submitted (which is a separate feature). UUID filenames prevent collisions across re-recordings.

**Alternatives considered**:
- Caches directory: Would survive between app launches, but recordings don't need to persist since submission is a separate feature.
- Documents directory: Inappropriate for temporary/draft content.

**Key implementation details**:
- `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")`
- Clean up with `FileManager.default.removeItem(at:)` when user discards or re-records
- On re-record: delete previous temp file, create new UUID-based URL

## 7. Swift 6.2 Concurrency Considerations

**Decision**: Keep `AVCaptureSession` management on a dedicated serial `DispatchQueue`. The recording delegate class inherits `NSObject` and is not an actor.

**Rationale**: AVFoundation classes are generally not `Sendable`. The blocking nature of `startRunning()`/`stopRunning()` requires a non-main-actor queue. The delegate protocol requires `NSObjectProtocol` conformance, ruling out actors.

**Key implementation details**:
- Dedicated `DispatchQueue(label: "dev.michaelfcollins3.standup.capture")` for session operations
- `AVCaptureFileOutputRecordingDelegate` class inherits `NSObject`
- `requestAccess(for:)` has a `@Sendable` completion handler and an async variant
- `VideoPlayer` is `@MainActor @preconcurrency` — used normally in SwiftUI views

## 8. Accessibility Design for Recording UI

**Decision**: Timer must use a secondary indicator (text label) alongside color to communicate urgency. All interactive elements must have VoiceOver labels. Dynamic Type must be supported for all text elements.

**Rationale**: Constitution Principle VIII requires VoiceOver, Dynamic Type, and WCAG 2.1 AA compliance. Color alone cannot convey information (WCAG 1.4.1). The countdown timer's color transitions (default → yellow → red) must be supplemented with accessible alternatives.

**Alternatives considered**: Haptic feedback for time warnings — good supplementary option but not sufficient as sole alternative to color.

**Key implementation details**:
- Circular progress gauge: use `.accessibilityLabel` with remaining time and urgency state
- Record/stop buttons: clear `.accessibilityLabel` and `.accessibilityHint`
- Timer text remains visible alongside the circular gauge for non-color-dependent time communication
- Support Dynamic Type for all text labels
- Announce timer state changes via `AccessibilityNotification.Announcement` at 10s and 5s marks
- Ensure minimum 4.5:1 contrast ratio for timer colors against background
