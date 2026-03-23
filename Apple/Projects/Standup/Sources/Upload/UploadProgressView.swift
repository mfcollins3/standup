// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Accessibility
import SwiftUI

// MARK: - UploadProgressView

struct UploadProgressView: View {
	@Environment(UploadService.self) private var uploadService
	@State private var showCancelConfirmation = false
	@State private var taskToCancel: UploadTask?

	var body: some View {
		List(uploadService.uploadTasks) { task in
			UploadTaskRow(task: task) {
				taskToCancel = task
				showCancelConfirmation = true
			} onRetry: {
				Task { try? await uploadService.retry(task: task) }
			}
			.frame(minHeight: 44)
		}
		.confirmationDialog(
			"Cancel Upload?",
			isPresented: $showCancelConfirmation,
			presenting: taskToCancel
		) { task in
			Button("Cancel Upload", role: .destructive) {
				uploadService.cancel(task: task)
			}
			Button("Keep Uploading", role: .cancel) { }
		} message: { _ in
			Text("The video will not be uploaded.")
		}
	}
}

// MARK: - UploadTaskRow

private struct UploadTaskRow: View {
	let task: UploadTask
	let onCancel: () -> Void
	let onRetry: () -> Void

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			switch task.status {
			case .pending:
				pendingRow
			case .uploading:
				uploadingRow
			case .retrying:
				retryingRow
			case .failed:
				failedRow
			case .cancelled:
				cancelledRow
			case .completed:
				completedRow
			}
		}
		.padding(.vertical, 4)
		.onChange(of: task.status) { _, newStatus in
			AccessibilityNotification.Announcement(statusAnnouncement(for: newStatus))
				.post()
		}
	}

	// MARK: Status Rows

	private var pendingRow: some View {
		HStack(spacing: 12) {
			if !reduceMotion {
				ProgressView()
					.accessibilityHidden(true)
			}
			Text("Waiting to upload…")
				.foregroundStyle(.secondary)
				.accessibilityLabel("Upload is pending")
		}
	}

	private var uploadingRow: some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				ProgressView(value: task.progress)
					.accessibilityLabel("Upload progress")
					.accessibilityValue("\(Int(task.progress * 100)) percent")
				Text("\(Int(task.progress * 100))%")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityHidden(true)
			}
			Spacer()
			Button("Cancel") {
				onCancel()
			}
			.frame(minWidth: 44, minHeight: 44)
			.accessibilityLabel("Cancel upload")
			.accessibilityHint("Cancels this video upload")
		}
	}

	private var retryingRow: some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				if !reduceMotion {
					ProgressView()
						.accessibilityHidden(true)
				}
				Text("Retry \(task.retryCount) of 3")
					.font(.caption)
					.foregroundStyle(.secondary)
					.accessibilityLabel("Retrying upload, attempt \(task.retryCount) of 3")
			}
			Spacer()
			Button("Cancel") {
				onCancel()
			}
			.frame(minWidth: 44, minHeight: 44)
			.accessibilityLabel("Cancel upload")
			.accessibilityHint("Cancels this upload and stops retrying")
		}
	}

	private var failedRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "exclamationmark.circle")
				.foregroundStyle(.red)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 2) {
				Text("Upload failed")
					.foregroundStyle(.red)
				if let message = task.errorMessage {
					Text(message)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.accessibilityElement(children: .combine)
			.accessibilityLabel(task.errorMessage.map { "Upload failed: \($0)" } ?? "Upload failed")

			Spacer()
			Button("Retry") {
				onRetry()
			}
			.frame(minWidth: 44, minHeight: 44)
			.accessibilityLabel("Retry upload")
			.accessibilityHint("Tries uploading this video again")
		}
	}

	private var cancelledRow: some View {
		HStack(spacing: 8) {
			Image(systemName: "xmark.circle")
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
			Text("Cancelled")
				.foregroundStyle(.secondary)
		}
		.accessibilityLabel("Upload was cancelled")
	}

	private var completedRow: some View {
		HStack(spacing: 8) {
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(.green)
				.accessibilityHidden(true)
			Text("Uploaded")
				.foregroundStyle(.primary)
		}
		.accessibilityLabel("Upload complete")
	}

	// MARK: Announcements

	private func statusAnnouncement(for status: UploadStatus) -> String {
		switch status {
		case .pending: "Upload is waiting"
		case .uploading: "Upload has started"
		case .retrying: "Upload is retrying, attempt \(task.retryCount) of 3"
		case .completed: "Upload complete"
		case .failed: task.errorMessage.map { "Upload failed: \($0)" } ?? "Upload failed"
		case .cancelled: "Upload was cancelled"
		}
	}
}
