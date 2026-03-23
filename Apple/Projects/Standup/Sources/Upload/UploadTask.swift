// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Foundation
import Observation

// MARK: - UploadStatus

enum UploadStatus: Equatable {
	case pending
	case uploading
	case retrying
	case completed
	case failed
	case cancelled
}

// MARK: - UploadTransitionError

enum UploadTransitionError: Error, Equatable {
	case invalidTransition(from: UploadStatus, to: UploadStatus)
}

// MARK: - UploadTask

/// Represents a single video upload from the device to Azure Blob Storage.
@Observable @MainActor
final class UploadTask: Identifiable {
	let id: UUID
	let videoFileURL: URL
	private(set) var status: UploadStatus
	private(set) var progress: Double
	var sasURL: URL?
	var sasExpiresAt: Date?
	private(set) var retryCount: Int
	var errorMessage: String?
	let createdAt: Date
	var urlSessionTaskIdentifier: Int?

	init(videoFileURL: URL) {
		self.id = UUID()
		self.videoFileURL = videoFileURL
		self.status = .pending
		self.progress = 0.0
		self.retryCount = 0
		self.createdAt = Date()
	}

	/// Transitions the task to a new status, validating the transition.
	/// Throws `UploadTransitionError.invalidTransition` for disallowed transitions.
	func transition(to newStatus: UploadStatus) throws {
		guard isValidTransition(from: status, to: newStatus) else {
			throw UploadTransitionError.invalidTransition(from: status, to: newStatus)
		}
		if newStatus == .retrying {
			retryCount += 1
		}
		if newStatus == .pending {
			retryCount = 0
		}
		status = newStatus
	}

	/// Updates upload progress, clamped to the range 0.0–1.0.
	func updateProgress(_ value: Double) {
		progress = max(0.0, min(1.0, value))
	}

	private func isValidTransition(from current: UploadStatus, to next: UploadStatus) -> Bool {
		switch (current, next) {
		case (.pending, .uploading): return true
		case (.pending, .cancelled): return true
		case (.uploading, .completed): return true
		case (.uploading, .retrying): return true
		case (.uploading, .cancelled): return true
		case (.retrying, .uploading): return true
		case (.retrying, .failed): return true
		case (.retrying, .cancelled): return true
		case (.failed, .pending): return true
		default: return false
		}
	}
}
