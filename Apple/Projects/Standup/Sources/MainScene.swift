// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import SwiftUI

struct MainScene: Scene {
	@State private var uploadService = UploadService(
		sasUrlClient: SasUrlClient(
			baseURL: URL(string: ProcessInfo.processInfo.environment["STANDUP_API_BASE_URL"] ?? "https://api.example.com")!,
			apiKey: ProcessInfo.processInfo.environment["STANDUP_API_KEY"] ?? ""
		)
	)

	var body: some Scene {
		WindowGroup("main_scene_title") {
			MainView()
				.environment(uploadService)
		}
	}
}
