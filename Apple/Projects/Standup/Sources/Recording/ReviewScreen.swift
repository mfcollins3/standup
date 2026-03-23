// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import SwiftUI

struct ReviewScreen: View {
    let videoURL: URL
    let viewModel: RecordingViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(UploadService.self) private var uploadService
    @State private var showDiscardAlert = false
    @State private var showUploadError = false
    @State private var uploadError: Error?

    var body: some View {
        VideoPlayerView(videoURL: videoURL)
            .ignoresSafeArea()
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        showDiscardAlert = true
                    } label: {
                        Label("Re-record", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Re-record")
                    .accessibilityHint("Discards this recording and returns to the camera")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        Task { await submitVideo() }
                    }
                    .accessibilityLabel("Submit video")
                    .accessibilityHint("Uploads this recording to your standup feed")
                }
            }
            .alert("Upload Failed", isPresented: $showUploadError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(uploadError?.localizedDescription ?? "An unknown error occurred.")
            }
            .alert("Discard Recording?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    viewModel.reRecord()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This recording will be deleted and you will return to the camera.")
            }
            .onDisappear {
                // Handle iOS back button — clean up if still in finished state
                if case .finished = viewModel.recordingState {
                    viewModel.reRecord()
                }
            }
    }

    private func submitVideo() async {
        do {
            try await uploadService.submit(videoAt: videoURL)
            dismiss()
        } catch {
            uploadError = error
            showUploadError = true
        }
    }
}
