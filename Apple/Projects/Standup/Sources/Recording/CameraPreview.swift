// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import AVFoundation
import SwiftUI
import UIKit

// MARK: - PreviewView

/// A UIView subclass that uses AVCaptureVideoPreviewLayer as its backing layer,
/// allowing the layer to resize automatically with the view.
final class PreviewView: UIView {
	override class var layerClass: AnyClass {
		AVCaptureVideoPreviewLayer.self
	}

	var previewLayer: AVCaptureVideoPreviewLayer {
		// swiftlint:disable:next force_cast
		layer as! AVCaptureVideoPreviewLayer
	}
}

// MARK: - CameraPreview

/// A SwiftUI view that displays a live camera preview using AVCaptureVideoPreviewLayer.
struct CameraPreview: UIViewRepresentable {
	let captureSession: AVCaptureSession

	func makeUIView(context: Context) -> PreviewView {
		let view = PreviewView()
		view.previewLayer.session = captureSession
		view.previewLayer.videoGravity = .resizeAspectFill
		return view
	}

	func updateUIView(_ uiView: PreviewView, context: Context) {
		// No updates needed; captureSession is set at creation time
	}
}
