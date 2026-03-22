// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import AVFoundation

// MARK: - RecordingSessionProtocol

protocol RecordingSessionProtocol: AnyObject, Sendable {
	var captureSession: AVCaptureSession { get }

	func startSession()
	func stopSession()
	func startRecording(to url: URL, completion: @Sendable @escaping (URL?, Error?) -> Void)
	func stopRecording()
}

// MARK: - RecordingSession

final class RecordingSession: NSObject, RecordingSessionProtocol, @unchecked Sendable {
	nonisolated(unsafe) let captureSession = AVCaptureSession()

	private let sessionQueue = DispatchQueue(
		label: "dev.michaelfcollins3.standup.capture",
		qos: .userInitiated
	)

	nonisolated(unsafe) private var movieOutput = AVCaptureMovieFileOutput()
	nonisolated(unsafe) private var completionHandler: (@Sendable (URL?, Error?) -> Void)?

	override init() {
		super.init()
		setupSession()
	}

	private func setupSession() {
		sessionQueue.async { [weak self] in
			guard let self else { return }
			captureSession.beginConfiguration()
			captureSession.sessionPreset = .high

			if let videoDevice = AVCaptureDevice.default(
				.builtInWideAngleCamera,
				for: .video,
				position: .front
			),
				let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
				captureSession.canAddInput(videoInput)
			{
				captureSession.addInput(videoInput)
			}

			if let audioDevice = AVCaptureDevice.default(for: .audio),
				let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
				captureSession.canAddInput(audioInput)
			{
				captureSession.addInput(audioInput)
			}

			if captureSession.canAddOutput(movieOutput) {
				captureSession.addOutput(movieOutput)
			}

			captureSession.commitConfiguration()
		}
	}

	func startSession() {
		sessionQueue.async { [weak self] in
			guard let self, !captureSession.isRunning else { return }
			captureSession.startRunning()
		}
	}

	func stopSession() {
		sessionQueue.async { [weak self] in
			guard let self, captureSession.isRunning else { return }
			captureSession.stopRunning()
		}
	}

	func startRecording(to url: URL, completion: @Sendable @escaping (URL?, Error?) -> Void) {
		sessionQueue.async { [weak self] in
			guard let self else { return }
			completionHandler = completion
			movieOutput.startRecording(to: url, recordingDelegate: self)
		}
	}

	func stopRecording() {
		sessionQueue.async { [weak self] in
			guard let self, movieOutput.isRecording else { return }
			movieOutput.stopRecording()
		}
	}
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension RecordingSession: AVCaptureFileOutputRecordingDelegate {
	func fileOutput(
		_ output: AVCaptureFileOutput,
		didFinishRecordingTo outputFileURL: URL,
		from connections: [AVCaptureConnection],
		error: Error?
	) {
		let handler = completionHandler
		completionHandler = nil

		if let error = error as NSError? {
			// Preserve partial video when recording was interrupted (e.g. incoming call)
			// or succeeded despite minor errors
			let partiallyRecorded = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
			if partiallyRecorded == true {
				handler?(outputFileURL, nil)
			} else {
				handler?(nil, error)
			}
		} else {
			handler?(outputFileURL, nil)
		}
	}
}
