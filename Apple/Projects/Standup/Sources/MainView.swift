// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import SwiftUI

struct MainView: View {
	var body: some View {
		NavigationStack {
			List {
				NavigationLink("Record Status Update") {
					RecordingScreen()
				}
				NavigationLink(String(localized: "Play Status Report")) {
					VideoPlaybackScreen(
						url: URL(string: "https://customer-j8jlsnmsytg4ne2z.cloudflarestream.com/2916cde874951283bc3cc8b7f3f9a9ba/manifest/video.m3u8")!
					)
				}
			}
			.navigationTitle("Standup")
		}
	}
}

#Preview {
	MainView()
}
