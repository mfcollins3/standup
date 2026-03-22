// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import SwiftUI
import UIKit

// MARK: - RecordingScreen

struct RecordingScreen: View {
	@Environment(\.scenePhase) private var scenePhase
	@State private var viewModel: RecordingViewModel
	@State private var showReview = false
	@State private var reviewURL: URL?

	init(viewModel: RecordingViewModel? = nil) {
		_viewModel = State(initialValue: viewModel ?? RecordingViewModel())
	}

	var body: some View {
		ZStack {
			backgroundLayer
			contentLayer
		}
		.navigationTitle("Record Update")
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await viewModel.checkPermissions()
			if viewModel.permissionStatus.isFullyAuthorized {
				viewModel.startPreview()
			}
		}
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .active else { return }
			Task {
				await viewModel.checkPermissions()
				if viewModel.permissionStatus.isFullyAuthorized {
					viewModel.startPreview()
				}
			}
		}
		.onChange(of: viewModel.recordingState) { _, newState in
			if case .finished(let url) = newState {
				reviewURL = url
				showReview = true
			}
		}
		.onDisappear {
			// If mid-recording when the view disappears (e.g. swipe-back), discard the recording.
			// If in any other state, simply stop the camera preview.
			if case .recording = viewModel.recordingState {
				viewModel.didNavigateAway()
			} else {
				viewModel.stopPreview()
			}
		}
		.navigationDestination(isPresented: $showReview) {
			if let url = reviewURL {
				ReviewScreen(videoURL: url, viewModel: viewModel)
			}
		}
	}

	// MARK: - Layers

	@ViewBuilder
	private var backgroundLayer: some View {
		if viewModel.permissionStatus.isFullyAuthorized {
			CameraPreview(captureSession: viewModel.captureSession)
				.ignoresSafeArea()
		} else {
			Color.black
				.ignoresSafeArea()
		}
	}

	@ViewBuilder
	private var contentLayer: some View {
		VStack {
			Spacer()

			// Timer overlay — only shown while recording
			if case .recording = viewModel.recordingState {
				CountdownTimerView(timerState: viewModel.timerState)
					.frame(width: 130, height: 130)
					.padding(.bottom, 24)
			}

			// Error banner
			if case .error(let message) = viewModel.recordingState {
				errorBanner(message: message)
					.padding(.horizontal)
					.padding(.bottom, 12)
			}

			// Permission required UI (shown when permission is determined but not granted)
			if !viewModel.permissionStatus.isFullyAuthorized
				&& !viewModel.permissionStatus.needsRequest
			{
				permissionDeniedContent
			}

			// Record / Stop control
			controlRow
				.padding(.bottom, 56)
		}
	}

	// MARK: - Control Row

	@ViewBuilder
	private var controlRow: some View {
		switch viewModel.recordingState {
		case .idle:
			recordButton
				.disabled(!viewModel.permissionStatus.isFullyAuthorized)

		case .recording:
			stopButton

		case .finished:
			EmptyView()

		case .error:
			recordButton
				.disabled(!viewModel.permissionStatus.isFullyAuthorized)
		}
	}

	private var recordButton: some View {
		Button {
			viewModel.startRecording()
		} label: {
			ZStack {
				Circle()
					.fill(.red)
					.frame(width: 80, height: 80)
				Circle()
					.stroke(.white, lineWidth: 4)
					.frame(width: 80, height: 80)
			}
		}
		.accessibilityLabel("Start recording")
		.accessibilityHint("Records a 30-second status video update")
	}

	private var stopButton: some View {
		Button {
			viewModel.stopRecording()
		} label: {
			ZStack {
				RoundedRectangle(cornerRadius: 14)
					.fill(.red)
					.frame(width: 80, height: 80)
				RoundedRectangle(cornerRadius: 14)
					.stroke(.white, lineWidth: 4)
					.frame(width: 80, height: 80)
			}
		}
		.accessibilityLabel("Stop recording")
		.accessibilityHint("Stops recording and shows the video for review")
	}

	// MARK: - Permission Denied

	private var permissionDeniedContent: some View {
		VStack(spacing: 16) {
			Image(systemName: "camera.fill")
				.font(.system(size: 48))
				.foregroundStyle(.white)

			Text("Camera & Microphone Access Required")
				.font(.headline)
				.foregroundStyle(.white)
				.multilineTextAlignment(.center)

			Text(
				"Naked Standup needs access to your camera and microphone to record status videos. "
					+ "Please grant access in Settings."
			)
			.font(.body)
			.foregroundStyle(.white.opacity(0.85))
			.multilineTextAlignment(.center)
			.padding(.horizontal)

			Button("Open Settings") {
				openAppSettings()
			}
			.buttonStyle(.borderedProminent)
			.accessibilityHint("Opens the Settings app where you can grant camera and microphone access")
		}
		.padding()
	}

	// MARK: - Error Banner

	private func errorBanner(message: String) -> some View {
		HStack(spacing: 12) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.white)
			Text(message)
				.font(.subheadline)
				.foregroundStyle(.white)
				.multilineTextAlignment(.leading)
		}
		.padding()
		.background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Recording error: \(message)")
	}

	// MARK: - Helpers

	private func openAppSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		UIApplication.shared.open(url)
	}
}

// MARK: - Preview

#Preview {
	NavigationStack {
		RecordingScreen()
	}
}
