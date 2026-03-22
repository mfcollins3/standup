// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import AVFoundation
import Observation
import UIKit

// MARK: - RecordingState

enum RecordingState: Equatable {
	case idle
	case recording
	case finished(URL)
	case error(String)
}

// MARK: - TimerUrgency

enum TimerUrgency: Equatable {
	case normal    // > 10 seconds remaining
	case warning   // 5 < remaining <= 10
	case critical  // remaining <= 5
}

// MARK: - TimerState

struct TimerState: Equatable {
	let totalDuration: TimeInterval
	var remainingTime: TimeInterval

	var urgency: TimerUrgency {
		switch remainingTime {
		case ...5:
			return .critical
		case ...10:
			return .warning
		default:
			return .normal
		}
	}

	var progress: Double {
		guard totalDuration > 0 else { return 0 }
		let clampedRemaining = max(0, min(remainingTime, totalDuration))
		return clampedRemaining / totalDuration
	}
}

// MARK: - RecordedVideo

struct RecordedVideo {
	let fileURL: URL
	let duration: TimeInterval
	let createdAt: Date
}

// MARK: - PermissionStatus

struct PermissionStatus: Equatable {
	var camera: AVAuthorizationStatus
	var microphone: AVAuthorizationStatus

	var isFullyAuthorized: Bool {
		camera == .authorized && microphone == .authorized
	}

	var needsRequest: Bool {
		camera == .notDetermined || microphone == .notDetermined
	}
}

// MARK: - RecordingViewModel

@Observable @MainActor
final class RecordingViewModel {
	var recordingState: RecordingState = .idle
	var timerState: TimerState
	var permissionStatus: PermissionStatus

	let totalDuration: TimeInterval

	var captureSession: AVCaptureSession {
		session.captureSession
	}

	private let session: any RecordingSessionProtocol
	private var timerTask: Task<Void, Never>?
	private var announcedWarningThreshold = false
	private var announcedCriticalThreshold = false

	init(
		session: any RecordingSessionProtocol,
		totalDuration: TimeInterval = 30.0,
		permissionStatus: PermissionStatus = PermissionStatus(
			camera: .notDetermined,
			microphone: .notDetermined
		)
	) {
		self.session = session
		self.totalDuration = totalDuration
		self.timerState = TimerState(totalDuration: totalDuration, remainingTime: totalDuration)
		self.permissionStatus = permissionStatus
	}

	convenience init() {
		self.init(session: RecordingSession())
	}

	// MARK: - Permissions

	func checkPermissions() async {
		var camera = AVCaptureDevice.authorizationStatus(for: .video)
		var microphone = AVCaptureDevice.authorizationStatus(for: .audio)

		if camera == .notDetermined {
			camera = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
		}
		if microphone == .notDetermined {
			microphone = await AVCaptureDevice.requestAccess(for: .audio) ? .authorized : .denied
		}

		permissionStatus = PermissionStatus(camera: camera, microphone: microphone)
	}

	// MARK: - Camera Preview

	func startPreview() {
		session.startSession()
	}

	func stopPreview() {
		session.stopSession()
	}

	// MARK: - Recording

	func startRecording() {
		guard permissionStatus.isFullyAuthorized else { return }
		guard case .idle = recordingState else { return }

		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("mov")

		recordingState = .recording
		timerState = TimerState(totalDuration: totalDuration, remainingTime: totalDuration)
		announcedWarningThreshold = false
		announcedCriticalThreshold = false

		session.startRecording(to: url) { [weak self] finishedURL, error in
			Task { @MainActor [weak self] in
				guard let self else { return }
				if let error {
					self.recordingState = .error(error.localizedDescription)
				} else if let finishedURL {
					// Only transition to .finished if still recording; otherwise the screen was
					// navigated away from (T023b) and we should discard the partial file
					if case .recording = self.recordingState {
						self.timerTask?.cancel()
						self.timerTask = nil
						self.recordingState = .finished(finishedURL)
					} else {
						try? FileManager.default.removeItem(at: finishedURL)
					}
				}
			}
		}

		startTimer()
	}

	func stopRecording() {
		guard case .recording = recordingState else { return }
		timerTask?.cancel()
		timerTask = nil
		session.stopRecording()
		// State transitions to .finished via the session's completion callback
	}

	/// Resets state and cleans up the recorded file so the user can re-record (T018).
	func reRecord() {
		if case .finished(let url) = recordingState {
			try? FileManager.default.removeItem(at: url)
		}

		timerTask?.cancel()
		timerTask = nil
		recordingState = .idle
		timerState = TimerState(totalDuration: totalDuration, remainingTime: totalDuration)
		announcedWarningThreshold = false
		announcedCriticalThreshold = false

		session.startSession()
	}

	/// Called when the user leaves the recording screen mid-recording (T023b).
	/// Discards any partial video when the completion callback arrives.
	func didNavigateAway() {
		guard case .recording = recordingState else { return }
		timerTask?.cancel()
		timerTask = nil
		// Transition to idle BEFORE stopping the session so the completion callback
		// sees the non-.recording state and deletes the partial file
		recordingState = .idle
		session.stopRecording()
		session.stopSession()
	}

	// MARK: - Private Timer

	private func startTimer() {
		timerTask = Task { @MainActor [weak self] in
			while true {
				try? await Task.sleep(for: .seconds(1))

				guard let self, !Task.isCancelled else { return }
				guard case .recording = self.recordingState else { return }

				let newTime = max(0, self.timerState.remainingTime - 1)
				self.timerState = TimerState(totalDuration: self.totalDuration, remainingTime: newTime)

				// Post accessibility announcements at urgency thresholds (T013)
				if !self.announcedCriticalThreshold && newTime <= 5 {
					self.announcedCriticalThreshold = true
					self.announcedWarningThreshold = true
					UIAccessibility.post(
						notification: .announcement,
						argument: "5 seconds remaining, wrapping up"
					)
				} else if !self.announcedWarningThreshold && newTime <= 10 {
					self.announcedWarningThreshold = true
					UIAccessibility.post(
						notification: .announcement,
						argument: "10 seconds remaining"
					)
				}

				if newTime <= 0 {
					self.stopRecording()
					return
				}
			}
		}
	}
}
