// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Foundation
import Testing
@testable import Standup

// MARK: - MockSasUrlClient

final class MockSasUrlClient: SasUrlFetching, @unchecked Sendable {
	var fetchResult: Result<SasUrlResponse, Error> = .success(
		SasUrlResponse(
			uploadUrl: "https://storage.test.local/blob?sv=2024",
			expiresAt: "2099-01-01T00:00:00Z"
		)
	)
	private(set) var fetchCallCount = 0

	func fetchSasUrl(for request: SasUrlRequest) async throws -> SasUrlResponse {
		fetchCallCount += 1
		return try fetchResult.get()
	}
}

// MARK: - MockUploadExecutor

final class MockUploadExecutor: UploadExecuting, @unchecked Sendable {
	struct UploadCall {
		let url: URL
		let fileURL: URL
		let headers: [String: String]
		let onProgress: @Sendable (Double) -> Void
		let onCompletion: @Sendable (Error?) -> Void
	}

	private(set) var uploadCalls: [UploadCall] = []
	private(set) var cancelledIdentifiers: [Int] = []

	func startUpload(
		to url: URL,
		from fileURL: URL,
		headers: [String: String],
		onProgress: @escaping @Sendable (Double) -> Void,
		onCompletion: @escaping @Sendable (Error?) -> Void
	) -> Int {
		uploadCalls.append(UploadCall(
			url: url,
			fileURL: fileURL,
			headers: headers,
			onProgress: onProgress,
			onCompletion: onCompletion
		))
		return uploadCalls.count
	}

	func cancelUpload(withIdentifier identifier: Int) {
		cancelledIdentifiers.append(identifier)
	}

	func simulateProgress(_ progress: Double, for index: Int = 0) {
		uploadCalls[index].onProgress(progress)
	}

	func simulateCompletion(_ error: Error? = nil, for index: Int = 0) {
		uploadCalls[index].onCompletion(error)
	}
}

// MARK: - Helpers

private let testVideoURL = URL(filePath: "/tmp/test-video.mp4")

@MainActor
private func makeService(
	sasClient: MockSasUrlClient = MockSasUrlClient(),
	executor: MockUploadExecutor = MockUploadExecutor(),
	retryDelayBase: Double = 0.0
) -> UploadService {
	UploadService(sasUrlClient: sasClient, uploadExecutor: executor, retryDelayBase: retryDelayBase)
}

// MARK: - UploadService Tests (T017, T020, T022, T026)

@Suite("UploadService")
struct UploadServiceTests {

	// MARK: T017: Submit + Upload Flow

	@Test("submit fetches a SAS URL")
	@MainActor func submitFetchesSasUrl() async throws {
		let sasClient = MockSasUrlClient()
		let executor = MockUploadExecutor()
		let service = makeService(sasClient: sasClient, executor: executor)
		try await service.submit(videoAt: testVideoURL)
		#expect(sasClient.fetchCallCount == 1)
	}

	@Test("submit starts the upload via the executor")
	@MainActor func submitStartsUpload() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		#expect(executor.uploadCalls.count == 1)
	}

	@Test("submit sets x-ms-blob-type header to BlockBlob")
	@MainActor func submitSetsBlobTypeHeader() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		#expect(executor.uploadCalls.first?.headers["x-ms-blob-type"] == "BlockBlob")
	}

	@Test("submit sets Content-Type header to video/mp4")
	@MainActor func submitSetsContentTypeHeader() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		#expect(executor.uploadCalls.first?.headers["Content-Type"] == "video/mp4")
	}

	@Test("task transitions to .uploading after submit")
	@MainActor func taskBecomesUploadingAfterSubmit() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		#expect(service.uploadTasks.first?.status == .uploading)
	}

	@Test("task transitions to .completed after successful upload")
	@MainActor func taskBecomesCompletedAfterSuccess() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(nil)
		await Task.yield()
		#expect(service.uploadTasks.first?.status == .completed)
	}

	@Test("task is tracked in uploadTasks after submit")
	@MainActor func taskTrackedInUploadTasks() async throws {
		let service = makeService()
		try await service.submit(videoAt: testVideoURL)
		#expect(service.uploadTasks.count == 1)
	}

	@Test("multiple concurrent uploads are tracked independently")
	@MainActor func multipleConcurrentUploadsTracked() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		let url1 = URL(filePath: "/tmp/video1.mp4")
		let url2 = URL(filePath: "/tmp/video2.mp4")
		try await service.submit(videoAt: url1)
		try await service.submit(videoAt: url2)
		#expect(service.uploadTasks.count == 2)
		#expect(executor.uploadCalls.count == 2)
	}

	// MARK: T020: Progress Tracking

	@Test("progress updates propagate to the upload task")
	@MainActor func progressUpdatesPropagateToTask() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateProgress(0.5)
		await Task.yield()
		#expect(abs((service.uploadTasks.first?.progress ?? 0) - 0.5) < 0.0001)
	}

	@Test("progress is clamped to 0.0–1.0 range")
	@MainActor func progressIsClamped() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateProgress(1.5)
		await Task.yield()
		#expect(service.uploadTasks.first?.progress == 1.0)
	}

	@Test("progress for task 1 does not affect task 2")
	@MainActor func progressIsIndependentPerTask() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: URL(filePath: "/tmp/v1.mp4"))
		try await service.submit(videoAt: URL(filePath: "/tmp/v2.mp4"))
		executor.simulateProgress(0.75, for: 0)
		await Task.yield()
		#expect(abs((service.uploadTasks[0].progress) - 0.75) < 0.0001)
		#expect(service.uploadTasks[1].progress == 0.0)
	}

	@Test("task progress is set to 1.0 on successful completion")
	@MainActor func progressIsFullOnCompletion() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(nil)
		await Task.yield()
		#expect(service.uploadTasks.first?.progress == 1.0)
	}

	// MARK: T022: Retry Logic

	@Test("transient error transitions task to .retrying")
	@MainActor func transientErrorTriggersRetry() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(URLError(.timedOut))
		await Task.yield()
		#expect(service.uploadTasks.first?.status == .retrying)
	}

	@Test("retryCount increments on each retry")
	@MainActor func retryCountIncrementsOnEachRetry() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor, retryDelayBase: 0.0)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(URLError(.timedOut))
		await Task.yield()
		#expect(service.uploadTasks.first?.retryCount == 1)
	}

	@Test("task transitions to .failed after max retries exceeded")
	@MainActor func taskFailsAfterMaxRetries() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor, retryDelayBase: 0.0)
		try await service.submit(videoAt: testVideoURL)

		// Exhaust all 3 retries
		for _ in 0..<3 {
			let lastIndex = executor.uploadCalls.count - 1
			executor.simulateCompletion(URLError(.timedOut), for: lastIndex)
			try await Task.sleep(for: .milliseconds(50))
		}

		#expect(service.uploadTasks.first?.status == .failed)
	}

	@Test("non-transient error transitions task directly to .failed")
	@MainActor func nonTransientErrorFails() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(URLError(.cannotFindHost))
		await Task.yield()
		#expect(service.uploadTasks.first?.status == .failed)
	}

	@Test("failed task can be manually retried via retry(task:)")
	@MainActor func manualRetryFromFailed() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor, retryDelayBase: 0.0)
		try await service.submit(videoAt: testVideoURL)

		// Exhaust retries
		for _ in 0..<3 {
			let lastIndex = executor.uploadCalls.count - 1
			executor.simulateCompletion(URLError(.timedOut), for: lastIndex)
			try await Task.sleep(for: .milliseconds(50))
		}

		#expect(service.uploadTasks.first?.status == .failed)

		try await service.retry(task: service.uploadTasks[0])
		#expect(service.uploadTasks.first?.status == .uploading)
		#expect(service.uploadTasks.first?.retryCount == 0)
	}

	@Test("SAS URL is re-fetched when expired before retry")
	@MainActor func sasUrlIsRefetchedWhenExpired() async throws {
		let sasClient = MockSasUrlClient()
		let executor = MockUploadExecutor()
		let service = makeService(sasClient: sasClient, executor: executor, retryDelayBase: 0.0)
		try await service.submit(videoAt: testVideoURL)
		// Mark SAS URL as already expired
		service.uploadTasks[0].sasExpiresAt = Date.distantPast
		executor.simulateCompletion(URLError(.timedOut))
		try await Task.sleep(for: .milliseconds(50))
		// Should have fetched SAS URL again
		#expect(sasClient.fetchCallCount >= 2)
	}

	// MARK: T026: Cancellation

	@Test("cancel transitions task to .cancelled")
	@MainActor func cancelTransitionsTaskToCancelled() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		service.cancel(task: service.uploadTasks[0])
		#expect(service.uploadTasks.first?.status == .cancelled)
	}

	@Test("cancel calls cancelUpload on the executor")
	@MainActor func cancelCallsExecutorCancel() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		let task = service.uploadTasks[0]
		service.cancel(task: task)
		#expect(executor.cancelledIdentifiers.count == 1)
	}

	@Test("cancel on .pending task transitions to .cancelled")
	@MainActor func cancelPendingTask() {
		let executor = MockUploadExecutor()
		let task = UploadTask(videoFileURL: testVideoURL)
		let service = makeService(executor: executor)
		// Directly inject a pending task (simulate manually)
		service.cancel(task: task)
		// Pending with no session identifier — cancel still transitions state
		#expect(task.status == .cancelled)
	}

	@Test("cancel on .completed task is a no-op for status")
	@MainActor func cancelCompletedTaskIsNoOp() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(nil)
		await Task.yield()
		#expect(service.uploadTasks.first?.status == .completed)
		service.cancel(task: service.uploadTasks[0])
		#expect(service.uploadTasks.first?.status == .completed)
	}

	@Test("cancel on .failed task is a no-op for status")
	@MainActor func cancelFailedTaskIsNoOp() async throws {
		let executor = MockUploadExecutor()
		let service = makeService(executor: executor)
		try await service.submit(videoAt: testVideoURL)
		executor.simulateCompletion(URLError(.cannotFindHost))
		await Task.yield()
		#expect(service.uploadTasks.first?.status == .failed)
		service.cancel(task: service.uploadTasks[0])
		#expect(service.uploadTasks.first?.status == .failed)
	}
}
