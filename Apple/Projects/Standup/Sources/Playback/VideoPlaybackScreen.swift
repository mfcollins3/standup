// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import AVKit
import Combine
import SwiftUI

// MARK: - VideoPlaybackViewModel

@Observable @MainActor
final class VideoPlaybackViewModel {
	private(set) var player: AVPlayer?
	private(set) var isLoading = true
	private(set) var errorMessage: String?

	private var cancellables = Set<AnyCancellable>()

	func load(url: URL) {
		let item = AVPlayerItem(url: url)
		let newPlayer = AVPlayer(playerItem: item)
		player = newPlayer

		item.publisher(for: \.status)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] status in
				switch status {
				case .readyToPlay:
					self?.isLoading = false
				case .failed:
					self?.isLoading = false
					self?.errorMessage = item.error?.localizedDescription
						?? String(localized: "The video could not be loaded.")
				default:
					break
				}
			}
			.store(in: &cancellables)

		newPlayer.play()
	}

	func cleanup() {
		cancellables.removeAll()
		player?.pause()
		player = nil
	}
}

// MARK: - VideoPlaybackScreen

struct VideoPlaybackScreen: View {
	let url: URL

	@State private var viewModel = VideoPlaybackViewModel()

	var body: some View {
		ZStack {
			if let player = viewModel.player {
				VideoPlayer(player: player)
			}

			if viewModel.isLoading && viewModel.errorMessage == nil {
				ProgressView()
					.scaleEffect(2)
					.accessibilityLabel(String(localized: "Loading video"))
			}

			if let message = viewModel.errorMessage {
				VStack(spacing: 16) {
					Image(systemName: "exclamationmark.triangle.fill")
						.font(.largeTitle)
						.foregroundStyle(.red)
					Text(message)
						.multilineTextAlignment(.center)
						.padding(.horizontal)
				}
				.accessibilityElement(children: .combine)
				.accessibilityLabel(String(localized: "Video playback failed: \(message)"))
			}
		}
		.navigationTitle("Play Status Report")
		.task {
			viewModel.load(url: url)
		}
		.onDisappear {
			viewModel.cleanup()
		}
	}
}

// MARK: - Preview

#Preview {
	NavigationStack {
		VideoPlaybackScreen(
			url: URL(string: "https://customer-j8jlsnmsytg4ne2z.cloudflarestream.com/2916cde874951283bc3cc8b7f3f9a9ba/manifest/video.m3u8")!
		)
	}
}
