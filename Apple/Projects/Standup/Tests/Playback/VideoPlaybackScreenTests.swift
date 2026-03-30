// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Foundation
import Testing
@testable import Standup

// MARK: - VideoPlaybackScreenTests

@Suite("VideoPlaybackScreen Tests") @MainActor
struct VideoPlaybackScreenTests {

	// MARK: - T002: Player Initialization

	@Test("VideoPlaybackViewModel initializes AVPlayer with the provided URL")
	func playerIsInitializedWithProvidedURL() {
		let url = URL(string: "https://example.com/video.m3u8")!
		let viewModel = VideoPlaybackViewModel()

		viewModel.load(url: url)

		#expect(viewModel.player != nil)
	}

	// MARK: - T003: Error State with Invalid URL

	@Test("VideoPlaybackViewModel transitions to error state when given an invalid URL")
	func errorStateWithInvalidURL() async throws {
		let invalidURL = URL(fileURLWithPath: "/nonexistent/video.m3u8")
		let viewModel = VideoPlaybackViewModel()

		viewModel.load(url: invalidURL)

		try await pollForCondition(timeout: .seconds(3)) {
			viewModel.errorMessage != nil
		}

		#expect(viewModel.errorMessage != nil)
		#expect(viewModel.isLoading == false)
	}

	// MARK: - T007: Error Message on AVPlayerItem Failure

	@Test("VideoPlaybackViewModel displays error message when AVPlayerItem status transitions to failed")
	func errorMessageDisplayedOnPlayerItemFailure() async throws {
		let failedURL = URL(fileURLWithPath: "/nonexistent/video.m3u8")
		let viewModel = VideoPlaybackViewModel()

		viewModel.load(url: failedURL)

		try await pollForCondition(timeout: .seconds(3)) {
			viewModel.errorMessage != nil
		}

		#expect(viewModel.errorMessage != nil)
	}

	// MARK: - T008: Stable State After Error and Navigation Back

	@Test("VideoPlaybackViewModel remains in stable state after error and navigation back")
	func stableStateAfterErrorAndCleanup() async throws {
		let failedURL = URL(fileURLWithPath: "/nonexistent/video.m3u8")
		let viewModel = VideoPlaybackViewModel()

		viewModel.load(url: failedURL)

		try await pollForCondition(timeout: .seconds(3)) {
			viewModel.errorMessage != nil
		}

		// Simulate navigation back (onDisappear calls cleanup)
		viewModel.cleanup()

		#expect(viewModel.player == nil)
	}

	// MARK: - Helpers

	private func pollForCondition(
		timeout: Duration,
		condition: () -> Bool
	) async throws {
		let deadline = ContinuousClock.now.advanced(by: timeout)
		while !condition() {
			if ContinuousClock.now >= deadline {
				throw PlaybackTestTimeoutError()
			}
			try await Task.sleep(for: .milliseconds(100))
		}
	}
}

// MARK: - PlaybackTestTimeoutError

private struct PlaybackTestTimeoutError: Error {
	var localizedDescription: String {
		String(localized: "Timed out waiting for playback condition.")
	}
}
