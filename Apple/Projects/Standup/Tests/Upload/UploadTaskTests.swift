// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Testing
@testable import Standup

// MARK: - Helpers

@MainActor
private func makeTask() -> UploadTask {
	UploadTask(videoFileURL: URL(filePath: "/tmp/test.mp4"))
}

// MARK: - UploadTask Tests (T013)

@Suite("UploadTask")
struct UploadTaskTests {

	@Test("initializing with a video file URL creates task in .pending status")
	@MainActor func initCreatesPendingTask() {
		let task = makeTask()
		#expect(task.status == .pending)
	}

	@Test("all UploadStatus cases exist")
	@MainActor func allStatusCasesExist() {
		let cases: [UploadStatus] = [.pending, .uploading, .retrying, .completed, .failed, .cancelled]
		#expect(cases.count == 6)
	}

	@Test("progress defaults to 0.0")
	@MainActor func progressDefaultsToZero() {
		let task = makeTask()
		#expect(task.progress == 0.0)
	}

	@Test("retryCount defaults to 0")
	@MainActor func retryCountDefaultsToZero() {
		let task = makeTask()
		#expect(task.retryCount == 0)
	}

	@Test("valid transition: pending → uploading")
	@MainActor func pendingToUploading() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		#expect(task.status == .uploading)
	}

	@Test("valid transition: pending → cancelled")
	@MainActor func pendingToCancelled() throws {
		let task = makeTask()
		try task.transition(to: .cancelled)
		#expect(task.status == .cancelled)
	}

	@Test("valid transition: uploading → completed")
	@MainActor func uploadingToCompleted() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .completed)
		#expect(task.status == .completed)
	}

	@Test("valid transition: uploading → retrying")
	@MainActor func uploadingToRetrying() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		#expect(task.status == .retrying)
	}

	@Test("valid transition: uploading → cancelled")
	@MainActor func uploadingToCancelled() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .cancelled)
		#expect(task.status == .cancelled)
	}

	@Test("valid transition: retrying → uploading")
	@MainActor func retryingToUploading() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		try task.transition(to: .uploading)
		#expect(task.status == .uploading)
	}

	@Test("valid transition: retrying → failed")
	@MainActor func retryingToFailed() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		try task.transition(to: .failed)
		#expect(task.status == .failed)
	}

	@Test("valid transition: retrying → cancelled")
	@MainActor func retryingToCancelled() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		try task.transition(to: .cancelled)
		#expect(task.status == .cancelled)
	}

	@Test("valid transition: failed → pending")
	@MainActor func failedToPending() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		try task.transition(to: .failed)
		try task.transition(to: .pending)
		#expect(task.status == .pending)
	}

	@Test("invalid transition: pending → completed throws")
	@MainActor func pendingToCompletedThrows() {
		let task = makeTask()
		#expect(throws: UploadTransitionError.self) {
			try task.transition(to: .completed)
		}
	}

	@Test("invalid transition: completed → uploading throws")
	@MainActor func completedToUploadingThrows() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .completed)
		#expect(throws: UploadTransitionError.self) {
			try task.transition(to: .uploading)
		}
	}

	@Test("invalid transition: pending → failed throws")
	@MainActor func pendingToFailedThrows() {
		let task = makeTask()
		#expect(throws: UploadTransitionError.self) {
			try task.transition(to: .failed)
		}
	}

	@Test("invalid transition: cancelled → uploading throws")
	@MainActor func cancelledToUploadingThrows() throws {
		let task = makeTask()
		try task.transition(to: .cancelled)
		#expect(throws: UploadTransitionError.self) {
			try task.transition(to: .uploading)
		}
	}

	@Test("progress clamps to 0.0 at minimum")
	@MainActor func progressClampsAtMinimum() {
		let task = makeTask()
		task.updateProgress(-0.5)
		#expect(task.progress == 0.0)
	}

	@Test("progress clamps to 1.0 at maximum")
	@MainActor func progressClampsAtMaximum() {
		let task = makeTask()
		task.updateProgress(1.5)
		#expect(task.progress == 1.0)
	}

	@Test("progress accepts values within 0.0–1.0 range")
	@MainActor func progressAcceptsValidRange() {
		let task = makeTask()
		task.updateProgress(0.67)
		#expect(abs(task.progress - 0.67) < 0.0001)
	}

	@Test("retryCount increments on transition to .retrying")
	@MainActor func retryCountIncrementsOnRetrying() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		#expect(task.retryCount == 1)
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		#expect(task.retryCount == 2)
	}

	@Test("retryCount resets to 0 on transition from failed → pending")
	@MainActor func retryCountResetsOnManualRetry() throws {
		let task = makeTask()
		try task.transition(to: .uploading)
		try task.transition(to: .retrying)
		try task.transition(to: .failed)
		#expect(task.retryCount == 1)
		try task.transition(to: .pending)
		#expect(task.retryCount == 0)
	}
}
