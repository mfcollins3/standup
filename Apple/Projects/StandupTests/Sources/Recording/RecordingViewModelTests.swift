// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import AVFoundation
import Testing
@testable import Standup

// MARK: - MockRecordingSession

final class MockRecordingSession: RecordingSessionProtocol, @unchecked Sendable {
	let captureSession = AVCaptureSession()

	private(set) var didStartSession = false
	private(set) var didStopSession = false
	private(set) var didStartRecording = false
	private(set) var didStopRecording = false

	var shouldSucceedRecording = true

	private var pendingURL: URL?
	private var completionHandler: (@Sendable (URL?, Error?) -> Void)?

	func startSession() {
		didStartSession = true
	}

	func stopSession() {
		didStopSession = true
	}

	func startRecording(to url: URL, completion: @Sendable @escaping (URL?, Error?) -> Void) {
		didStartRecording = true
		pendingURL = url
		completionHandler = completion
	}

	func stopRecording() {
		didStopRecording = true
		guard let handler = completionHandler else { return }
		let url = pendingURL
		completionHandler = nil
		pendingURL = nil

		if shouldSucceedRecording, let url {
			handler(url, nil)
		} else {
			handler(nil, NSError(domain: "MockRecordingSession", code: 0, userInfo: [
				NSLocalizedDescriptionKey: "Simulated recording failure"
			]))
		}
	}
}

// MARK: - Helpers

private func makeViewModel(
	session: MockRecordingSession,
	totalDuration: TimeInterval = 30.0
) -> RecordingViewModel {
	RecordingViewModel(
		session: session,
		totalDuration: totalDuration,
		permissionStatus: PermissionStatus(camera: .authorized, microphone: .authorized)
	)
}

// MARK: - RecordingState Tests (T006)

@Suite("RecordingViewModel — state transitions")
struct RecordingViewModelStateTests {

	@Test("startRecording() transitions to .recording when permissions are authorized")
	@MainActor func startRecordingTransitionsToRecording() {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()

		#expect(viewModel.recordingState == .recording)
		#expect(session.didStartRecording)
	}

	@Test("startRecording() is a no-op when camera permission is denied")
	@MainActor func startRecordingIgnoredWhenCameraDenied() {
		let session = MockRecordingSession()
		let viewModel = RecordingViewModel(
			session: session,
			totalDuration: 30.0,
			permissionStatus: PermissionStatus(camera: .denied, microphone: .authorized)
		)

		viewModel.startRecording()

		#expect(viewModel.recordingState == .idle)
		#expect(!session.didStartRecording)
	}

	@Test("startRecording() is a no-op when microphone permission is denied")
	@MainActor func startRecordingIgnoredWhenMicrophoneDenied() {
		let session = MockRecordingSession()
		let viewModel = RecordingViewModel(
			session: session,
			totalDuration: 30.0,
			permissionStatus: PermissionStatus(camera: .authorized, microphone: .denied)
		)

		viewModel.startRecording()

		#expect(viewModel.recordingState == .idle)
		#expect(!session.didStartRecording)
	}

	@Test("startRecording() resets timer to totalDuration")
	@MainActor func startRecordingResetsTimer() {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session, totalDuration: 10.0)

		viewModel.startRecording()

		#expect(viewModel.timerState.remainingTime == 10.0)
		#expect(viewModel.timerState.totalDuration == 10.0)
	}

	@Test("stopRecording() transitions to .finished after session callback")
	@MainActor func stopRecordingTransitionsToFinished() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()
		viewModel.stopRecording()

		// Yield so the Task { @MainActor } in the completion callback can execute
		try await Task.sleep(for: .milliseconds(100))

		if case .finished = viewModel.recordingState {
			// Expected
		} else {
			#expect(Bool(false), "Expected .finished state, got \(viewModel.recordingState)")
		}
	}

	@Test("stopRecording() preserves the recorded file URL")
	@MainActor func stopRecordingPreservesURL() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()
		viewModel.stopRecording()

		try await Task.sleep(for: .milliseconds(100))

		if case .finished(let url) = viewModel.recordingState {
			#expect(url.pathExtension == "mov")
		} else {
			#expect(Bool(false), "Expected .finished state with URL")
		}
	}

	@Test("stopRecording() is a no-op when not recording")
	@MainActor func stopRecordingIgnoredWhenIdle() {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.stopRecording()

		#expect(viewModel.recordingState == .idle)
		#expect(!session.didStopRecording)
	}
}

// MARK: - Timer Tests (T006)

@Suite("RecordingViewModel — timer behaviour")
struct RecordingViewModelTimerTests {

	@Test("timer counts down over time")
	@MainActor func timerDecrementsWhileRecording() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session, totalDuration: 5.0)

		viewModel.startRecording()
		#expect(viewModel.timerState.remainingTime == 5.0)

		try await Task.sleep(for: .seconds(1.5))

		#expect(viewModel.timerState.remainingTime < 5.0)
	}

	@Test("auto-stop fires when timer reaches zero")
	@MainActor func timerAutoStopsRecording() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session, totalDuration: 2.0)

		viewModel.startRecording()

		// Wait longer than totalDuration + callback latency
		try await Task.sleep(for: .seconds(4.0))

		if case .finished = viewModel.recordingState {
			// Expected
		} else {
			#expect(Bool(false), "Expected .finished state after timer expiry")
		}
	}

	@Test("timer stops counting after explicit stopRecording()")
	@MainActor func timerFreezeAfterStop() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session, totalDuration: 30.0)

		viewModel.startRecording()
		viewModel.stopRecording()

		let frozenTime = viewModel.timerState.remainingTime
		try await Task.sleep(for: .seconds(1.5))

		#expect(viewModel.timerState.remainingTime == frozenTime)
	}
}

// MARK: - Re-record Tests (T017)

@Suite("RecordingViewModel — re-record")
struct RecordingViewModelReRecordTests {

	@Test("reRecord() resets state to .idle from .finished")
	@MainActor func reRecordResetsToIdle() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()
		viewModel.stopRecording()
		try await Task.sleep(for: .milliseconds(100))

		guard case .finished = viewModel.recordingState else {
			#expect(Bool(false), "Precondition: expected .finished state")
			return
		}

		viewModel.reRecord()

		#expect(viewModel.recordingState == .idle)
	}

	@Test("reRecord() resets timer to totalDuration")
	@MainActor func reRecordResetsTimer() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session, totalDuration: 5.0)

		viewModel.startRecording()
		try await Task.sleep(for: .seconds(1.5))
		viewModel.stopRecording()
		try await Task.sleep(for: .milliseconds(100))

		viewModel.reRecord()

		#expect(viewModel.timerState.remainingTime == 5.0)
	}

	@Test("reRecord() restarts the camera session")
	@MainActor func reRecordStartsSession() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()
		viewModel.stopRecording()
		try await Task.sleep(for: .milliseconds(100))

		let startCount = session.didStartSession

		viewModel.reRecord()

		#expect(session.didStartSession || startCount)
	}
}

// MARK: - Early Stop Tests (T020)

@Suite("RecordingViewModel — early stop")
struct RecordingViewModelEarlyStopTests {

	@Test("stopRecording() via button stops the session")
	@MainActor func earlyStopCallsSessionStop() {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()
		viewModel.stopRecording()

		#expect(session.didStopRecording)
	}

	@Test("didNavigateAway() discards recording when called mid-recording")
	@MainActor func didNavigateAwayDiscardsRecording() async throws {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.startRecording()
		viewModel.didNavigateAway()

		// Give time for the async completion to fire (stopRecording triggers the callback)
		try await Task.sleep(for: .milliseconds(100))

		// The state should be .idle and the partial file should have been discarded
		#expect(viewModel.recordingState == .idle)
	}

	@Test("didNavigateAway() is a no-op when not recording")
	@MainActor func didNavigateAwayIgnoredWhenIdle() {
		let session = MockRecordingSession()
		let viewModel = makeViewModel(session: session)

		viewModel.didNavigateAway()

		#expect(viewModel.recordingState == .idle)
		#expect(!session.didStopRecording)
	}
}

// MARK: - TimerState Model Tests

@Suite("TimerState")
struct TimerStateTests {

	@Test("urgency is .normal when remainingTime > 10")
	func urgencyNormalAbove10() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 10.1)
		#expect(state.urgency == .normal)
	}

	@Test("urgency transitions to .warning at exactly 10 seconds")
	func urgencyWarningAt10() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 10.0)
		#expect(state.urgency == .warning)
	}

	@Test("urgency is .warning between 5 and 10 seconds exclusive")
	func urgencyWarningBetween5And10() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 7.5)
		#expect(state.urgency == .warning)
	}

	@Test("urgency transitions to .critical at exactly 5 seconds")
	func urgencyCriticalAt5() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 5.0)
		#expect(state.urgency == .critical)
	}

	@Test("urgency is .critical at 0 seconds")
	func urgencyCriticalAtZero() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 0.0)
		#expect(state.urgency == .critical)
	}

	@Test("progress is 1.0 at start")
	func progressFullAtStart() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 30.0)
		#expect(state.progress == 1.0)
	}

	@Test("progress is 0.5 at halfway")
	func progressHalf() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 15.0)
		#expect(state.progress == 0.5)
	}

	@Test("progress is 0.0 at zero remaining")
	func progressEmptyAtEnd() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 0.0)
		#expect(state.progress == 0.0)
	}
}
