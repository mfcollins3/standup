// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let videoURL: URL

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .task {
                player = AVPlayer(url: videoURL)
            }
    }
}
