// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Foundation

// MARK: - UploadExecuting Protocol

protocol UploadExecuting: AnyObject {
	func startUpload(
		to url: URL,
		from fileURL: URL,
		headers: [String: String],
		onProgress: @escaping @Sendable (Double) -> Void,
		onCompletion: @escaping @Sendable (Error?) -> Void
	) -> Int

	func cancelUpload(withIdentifier identifier: Int)
}

// MARK: - CellularUploadPreference

struct CellularUploadPreference {
	private let defaults: UserDefaults
	private let key = "app.nakedstandup.allowCellularUpload"

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	var isSet: Bool {
		defaults.object(forKey: key) != nil
	}

	var allowsCellular: Bool {
		get { defaults.bool(forKey: key) }
		set { defaults.set(newValue, forKey: key) }
	}
}

// MARK: - BackgroundUploadExecutor

final class BackgroundUploadExecutor: NSObject, UploadExecuting, @unchecked Sendable {
	private let lock = NSLock()
	private var progressHandlers: [Int: @Sendable (Double) -> Void] = [:]
	private var completionHandlers: [Int: @Sendable (Error?) -> Void] = [:]
	private var nextIdentifier = 1
	private lazy var urlSession: URLSession = {
		let config = URLSessionConfiguration.background(
			withIdentifier: "app.nakedstandup.upload"
		)
		config.isDiscretionary = false
		config.sessionSendsLaunchEvents = true
		return URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}()

	func startUpload(
		to url: URL,
		from fileURL: URL,
		headers: [String: String],
		onProgress: @escaping @Sendable (Double) -> Void,
		onCompletion: @escaping @Sendable (Error?) -> Void
	) -> Int {
		lock.lock()
		let identifier = nextIdentifier
		nextIdentifier += 1
		progressHandlers[identifier] = onProgress
		completionHandlers[identifier] = onCompletion
		lock.unlock()

		var request = URLRequest(url: url)
		request.httpMethod = "PUT"
		for (key, value) in headers {
			request.setValue(value, forHTTPHeaderField: key)
		}

		let task = urlSession.uploadTask(with: request, fromFile: fileURL)
		task.taskIdentifier
		// Store mapping from URLSessionTask.taskIdentifier to our identifier
		lock.lock()
		sessionToOurIdentifier[task.taskIdentifier] = identifier
		lock.unlock()

		task.resume()
		return identifier
	}

	func cancelUpload(withIdentifier identifier: Int) {
		lock.lock()
		let sessionTaskId = ourToSessionIdentifier[identifier]
		progressHandlers.removeValue(forKey: identifier)
		completionHandlers.removeValue(forKey: identifier)
		lock.unlock()

		if let sessionTaskId {
			urlSession.getAllTasks { tasks in
				tasks.first { $0.taskIdentifier == sessionTaskId }?.cancel()
			}
		}
	}

	// Bidirectional mapping between our stable identifier and URLSessionTask.taskIdentifier
	private var sessionToOurIdentifier: [Int: Int] = [:]
	private var ourToSessionIdentifier: [Int: Int] = [:]

	private func registerMapping(sessionTaskId: Int, ourId: Int) {
		lock.lock()
		sessionToOurIdentifier[sessionTaskId] = ourId
		ourToSessionIdentifier[ourId] = sessionTaskId
		lock.unlock()
	}
}

extension BackgroundUploadExecutor: URLSessionTaskDelegate {
	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didSendBodyData bytesSent: Int64,
		totalBytesSent: Int64,
		totalBytesExpectedToSend: Int64
	) {
		guard totalBytesExpectedToSend > 0 else { return }
		let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
		lock.lock()
		let ourId = sessionToOurIdentifier[task.taskIdentifier]
		let handler = ourId.flatMap { progressHandlers[$0] }
		lock.unlock()
		handler?(progress)
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: Error?
	) {
		lock.lock()
		let ourId = sessionToOurIdentifier[task.taskIdentifier]
		let handler = ourId.flatMap { completionHandlers[$0] }
		if let ourId {
			completionHandlers.removeValue(forKey: ourId)
			sessionToOurIdentifier.removeValue(forKey: task.taskIdentifier)
			ourToSessionIdentifier.removeValue(forKey: ourId)
		}
		lock.unlock()
		handler?(error)
	}
}

// MARK: - UploadService

@Observable @MainActor
final class UploadService {
	let retryDelayBase: Double
	private let maxRetries = 3
	private let sasUrlClient: SasUrlFetching
	private let uploadExecutor: UploadExecuting
	private(set) var uploadTasks: [UploadTask] = []
	private var retryTasks: [UUID: Task<Void, Never>] = [:]

	init(
		sasUrlClient: SasUrlFetching,
		uploadExecutor: UploadExecuting = BackgroundUploadExecutor(),
		retryDelayBase: Double = 2.0
	) {
		self.sasUrlClient = sasUrlClient
		self.uploadExecutor = uploadExecutor
		self.retryDelayBase = retryDelayBase
	}

	func submit(videoAt fileURL: URL) async throws {
		let task = UploadTask(videoFileURL: fileURL)
		uploadTasks.append(task)
		try await startUpload(for: task)
	}

	func retry(task: UploadTask) async throws {
		retryTasks[task.id]?.cancel()
		retryTasks[task.id] = nil
		try task.transition(to: .pending)
		task.errorMessage = nil
		try await startUpload(for: task)
	}

	func cancel(task: UploadTask) {
		retryTasks[task.id]?.cancel()
		retryTasks[task.id] = nil
		if let identifier = task.urlSessionTaskIdentifier {
			uploadExecutor.cancelUpload(withIdentifier: identifier)
		}
		guard task.status != .completed && task.status != .failed else { return }
		try? task.transition(to: .cancelled)
	}

	// MARK: - Private

	private func startUpload(for task: UploadTask) async throws {
		let request = SasUrlRequest(
			contentType: "video/mp4",
			fileSizeBytes: fileSizeBytes(at: task.videoFileURL)
		)
		let sasResponse: SasUrlResponse
		// Re-fetch SAS URL if not set or expired
		if let existingURL = task.sasURL,
		   let expiresAt = task.sasExpiresAt,
		   expiresAt > Date() {
			sasResponse = SasUrlResponse(uploadUrl: existingURL.absoluteString, expiresAt: expiresAt.ISO8601Format())
		} else {
			sasResponse = try await sasUrlClient.fetchSasUrl(for: request)
			task.sasURL = URL(string: sasResponse.uploadUrl)
			task.sasExpiresAt = ISO8601DateFormatter().date(from: sasResponse.expiresAt)
		}

		guard let uploadURL = URL(string: sasResponse.uploadUrl) else {
			throw SasUrlClientError.invalidResponse
		}

		try task.transition(to: .uploading)
		let identifier = launchUpload(for: task, to: uploadURL)
		task.urlSessionTaskIdentifier = identifier
	}

	private func launchUpload(for task: UploadTask, to url: URL) -> Int {
		let headers: [String: String] = [
			"x-ms-blob-type": "BlockBlob",
			"Content-Type": "video/mp4"
		]
		let taskId = task.id
		let identifier = uploadExecutor.startUpload(
			to: url,
			from: task.videoFileURL,
			headers: headers,
			onProgress: { [weak self] progress in
				Task { @MainActor [weak self] in
					self?.handleProgress(taskId: taskId, progress: progress)
				}
			},
			onCompletion: { [weak self] error in
				Task { @MainActor [weak self] in
					self?.handleCompletion(taskId: taskId, error: error)
				}
			}
		)
		return identifier
	}

	private func handleProgress(taskId: UUID, progress: Double) {
		guard let task = uploadTasks.first(where: { $0.id == taskId }) else { return }
		task.updateProgress(progress)
	}

	private func handleCompletion(taskId: UUID, error: Error?) {
		guard let task = uploadTasks.first(where: { $0.id == taskId }) else { return }
		task.urlSessionTaskIdentifier = nil

		if let error {
			let urlError = error as? URLError
			if task.retryCount < maxRetries && isTransientError(urlError) {
				try? task.transition(to: .retrying)
				scheduleRetry(for: task)
			} else {
				try? task.transition(to: .failed)
				task.errorMessage = error.localizedDescription
			}
		} else {
			task.updateProgress(1.0)
			try? task.transition(to: .completed)
		}
	}

	private func scheduleRetry(for task: UploadTask) {
		let delay = retryDelayBase * pow(2.0, Double(task.retryCount - 1))
		let retryTask = Task { @MainActor [weak self] in
			try? await Task.sleep(for: .seconds(delay))
			guard !Task.isCancelled else { return }
			guard let self else { return }
			// Reset SAS URL if near expiry before re-uploading
			if let expiresAt = task.sasExpiresAt, expiresAt <= Date() {
				task.sasURL = nil
				task.sasExpiresAt = nil
			}
			try? await self.startUpload(for: task)
		}
		retryTasks[task.id] = retryTask
	}

	private func isTransientError(_ urlError: URLError?) -> Bool {
		guard let urlError else { return false }
		switch urlError.code {
		case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
			return true
		default:
			return false
		}
	}

	private func fileSizeBytes(at url: URL) -> Int64 {
		let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
		return Int64(size)
	}
}
