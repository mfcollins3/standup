# 001 - Use AVFoundation for Video Capture

**Status:** Accepted

**Date:** 2026-01-01

---

## Context

Naked Standup allows team members to record short video updates (up to 30 seconds) from an iOS
device. The application needs to access the device camera and microphone, capture video with audio,
and save the recording to a temporary file that can be reviewed before submission.

iOS provides two main frameworks for video capture:

- **AVFoundation** – A low-level framework giving direct access to the capture pipeline. It provides
  `AVCaptureSession`, `AVCaptureDevice`, `AVCaptureMovieFileOutput`, and a delegate-based API for
  fine-grained control over the recording lifecycle.
- **UIImagePickerController / PHPickerViewController** – Higher-level system UI controllers that
  manage camera access and recording on behalf of the application. They are simpler to integrate but
  provide very limited control over the user interface and recording parameters.

The feature requirements include a custom countdown timer overlay, per-frame camera preview
embedded within the application's own navigation hierarchy, and the ability to recover a partial
recording when the user's device disk is full or when the session is interrupted by a system event
(e.g. an incoming phone call). These requirements cannot be satisfied by the high-level picker APIs.

---

## Decision

We will use **AVFoundation** as the video capture framework for Naked Standup.

### Protocol abstraction

To keep the ViewModel testable without requiring a physical device or camera hardware, the
AVFoundation session is hidden behind a protocol:

```swift
protocol RecordingSessionProtocol: AnyObject, Sendable {
    var captureSession: AVCaptureSession { get }
    func startSession()
    func stopSession()
    func startRecording(to url: URL, completion: @Sendable @escaping (URL?, Error?) -> Void)
    func stopRecording()
}
```

`RecordingViewModel` depends on `any RecordingSessionProtocol`. Unit tests inject a
`MockRecordingSession` that immediately calls the completion handler without touching AVFoundation.
The production app uses `RecordingSession`, which wraps the real AVFoundation pipeline.

### Concurrency model

AVFoundation objects are not `Sendable`. Swift 6.2 strict concurrency mode would normally reject
storing them in `@MainActor`-isolated types. We address this with two patterns:

1. **`nonisolated(unsafe)` storage** – AVFoundation properties (`captureSession`, `movieOutput`,
   `completionHandler`) are declared `nonisolated(unsafe)`. This suppresses the sendability check
   and is safe because all mutations happen exclusively on `sessionQueue`.

2. **Dedicated serial queue** – All AVFoundation mutation (session configuration, start/stop
   recording) runs on `sessionQueue`, a private `DispatchQueue` with `.userInitiated` QoS. The
   queue acts as the synchronisation domain for the AVFoundation objects, equivalent to the actor
   isolation that Swift's concurrency model would otherwise provide.

```swift
final class RecordingSession: NSObject, RecordingSessionProtocol, @unchecked Sendable {
    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(
        label: "dev.michaelfcollins3.standup.capture",
        qos: .userInitiated
    )
    nonisolated(unsafe) private var movieOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) private var completionHandler: (@Sendable (URL?, Error?) -> Void)?
}
```

### Partial recording preservation

When the device disk becomes full or the system interrupts the session (e.g., incoming phone call),
AVFoundation calls `fileOutput(_:didFinishRecordingTo:error:)` with a non-nil error. In many cases
the framework has already written a usable partial file to disk. We examine the
`AVErrorRecordingSuccessfullyFinishedKey` user-info key to detect this case and pass the partial
URL to the completion handler rather than discarding it:

```swift
func fileOutput(
    _ output: AVCaptureFileOutput,
    didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection],
    error: Error?
) {
    let successfullyFinished = (error as NSError?)
        .flatMap { $0.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool }
        ?? true

    if successfullyFinished {
        completionHandler?(outputFileURL, nil)
    } else {
        completionHandler?(nil, error)
    }
    completionHandler = nil
}
```

### Camera preview bridge

SwiftUI does not have a built-in AVFoundation preview component. We bridge the gap with a
`UIViewRepresentable` that hosts a `UIView` whose `layerClass` is `AVCaptureVideoPreviewLayer`.
This is the approach recommended by Apple because it uses the GPU compositing path and avoids
copying pixel buffers:

```swift
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let captureSession: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) { }
}
```

### ViewModel pattern

`RecordingViewModel` is declared `@Observable @MainActor`. It drives all UI state transitions and
owns the timer loop. The timer is implemented as a Swift structured-concurrency `Task` to integrate
naturally with `@Observable` and to simplify cancellation:

```swift
private func startTimer() {
    timerTask = Task { @MainActor [weak self] in
        while let self, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            // update timerState and announce accessibility milestones
        }
    }
}
```

---

## Architecture diagram

```mermaid
graph TD
    subgraph SwiftUI Layer
        A[StandupApp] --> B[MainView]
        B --> C[RecordingScreen]
        C --> D[CameraPreview\nUIViewRepresentable]
        C --> E[CountdownTimerView]
        C --> F[ReviewScreen]
        F --> G[VideoPlayerView\nAVKit.VideoPlayer]
    end

    subgraph ViewModel Layer
        H[RecordingViewModel\n@Observable @MainActor]
    end

    subgraph Session Layer
        I[RecordingSessionProtocol]
        J[RecordingSession\nAVFoundation]
        K[MockRecordingSession\nTests only]
    end

    C --> H
    F --> H
    H --> I
    I --> J
    I --> K
    D --> J
```

---

## Consequences

**Positive:**

- Full control over the camera preview, recording parameters, and UI layout.
- Partial recordings are recoverable when the session is interrupted, improving the user experience.
- `RecordingSessionProtocol` makes the ViewModel fully unit-testable without hardware.
- The `@Observable @MainActor` + structured concurrency pattern is idiomatic for Swift 6.2.

**Negative:**

- More boilerplate than `UIImagePickerController`. The team must maintain the AVFoundation
  integration across iOS SDK updates.
- `@unchecked Sendable` on `RecordingSession` opts out of compile-time data-race checking for that
  type. The manual queue-based discipline must be maintained carefully during future changes.
- Future contributors must understand the `nonisolated(unsafe)` + dedicated-queue pattern to safely
  extend `RecordingSession`.
