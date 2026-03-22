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
			}
			.navigationTitle("Standup")
		}
	}
}

#Preview {
	MainView()
}
