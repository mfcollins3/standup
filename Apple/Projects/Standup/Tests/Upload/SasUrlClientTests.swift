// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Foundation
import Testing
@testable import Standup

// MARK: - Mock URLProtocol

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
	static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let handler = MockURLProtocol.requestHandler else {
			client?.urlProtocol(self, didFailWithError: URLError(.unknown))
			return
		}
		do {
			let (response, data) = try handler(request)
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}

// MARK: - Helpers

private func makeMockSession() -> URLSession {
	let config = URLSessionConfiguration.ephemeral
	config.protocolClasses = [MockURLProtocol.self]
	return URLSession(configuration: config)
}

private func makeClient(_ session: URLSession = makeMockSession()) -> SasUrlClient {
	SasUrlClient(
		baseURL: URL(string: "https://api.test.local")!,
		apiKey: "test-api-key",
		urlSession: session
	)
}

private func makeSasUrlRequest() -> SasUrlRequest {
	SasUrlRequest(contentType: "video/mp4", fileSizeBytes: 1_024_000)
}

private func makeJSONResponse(statusCode: Int, body: [String: Any]) -> (HTTPURLResponse, Data) {
	let response = HTTPURLResponse(
		url: URL(string: "https://api.test.local/video")!,
		statusCode: statusCode,
		httpVersion: nil,
		headerFields: nil
	)!
	let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
	return (response, data)
}

// MARK: - SasUrlClient Tests (T014)

@Suite(.serialized, "SasUrlClient")
struct SasUrlClientTests {

	@Test("200 response decodes SasUrlResponse")
	func successDecodesSasUrlResponse() async throws {
		MockURLProtocol.requestHandler = { _ in
			makeJSONResponse(statusCode: 200, body: [
				"uploadUrl": "https://storage.test.local/blob?sv=2024",
				"expiresAt": "2026-01-01T12:00:00Z"
			])
		}
		let response = try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		#expect(response.uploadUrl == "https://storage.test.local/blob?sv=2024")
		#expect(response.expiresAt == "2026-01-01T12:00:00Z")
	}

	@Test("request includes X-Api-Key header")
	func requestIncludesApiKeyHeader() async throws {
		var capturedRequest: URLRequest?
		MockURLProtocol.requestHandler = { request in
			capturedRequest = request
			return makeJSONResponse(statusCode: 200, body: [
				"uploadUrl": "https://x",
				"expiresAt": "2026-01-01T00:00:00Z"
			])
		}
		_ = try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		#expect(capturedRequest?.value(forHTTPHeaderField: "X-Api-Key") == "test-api-key")
	}

	@Test("request encodes contentType and fileSizeBytes in body")
	func requestBodyEncodesFields() async throws {
		var capturedRequest: URLRequest?
		MockURLProtocol.requestHandler = { request in
			capturedRequest = request
			return makeJSONResponse(statusCode: 200, body: [
				"uploadUrl": "https://x",
				"expiresAt": "2026-01-01T00:00:00Z"
			])
		}
		let req = SasUrlRequest(contentType: "video/mp4", fileSizeBytes: 5_000_000)
		_ = try await makeClient().fetchSasUrl(for: req)
		let body = try JSONDecoder().decode(SasUrlRequest.self, from: capturedRequest!.httpBody!)
		#expect(body.contentType == "video/mp4")
		#expect(body.fileSizeBytes == 5_000_000)
	}

	@Test("request uses POST method")
	func requestUsesPostMethod() async throws {
		var capturedRequest: URLRequest?
		MockURLProtocol.requestHandler = { request in
			capturedRequest = request
			return makeJSONResponse(statusCode: 200, body: [
				"uploadUrl": "https://x",
				"expiresAt": "2026-01-01T00:00:00Z"
			])
		}
		_ = try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		#expect(capturedRequest?.httpMethod == "POST")
	}

	@Test("400 response throws .invalidRequest")
	func badRequestThrowsInvalidRequest() async throws {
		MockURLProtocol.requestHandler = { _ in
			let response = HTTPURLResponse(
				url: URL(string: "https://api.test.local/video")!,
				statusCode: 400,
				httpVersion: nil,
				headerFields: nil
			)!
			return (response, "Bad request".data(using: .utf8)!)
		}
		await #expect(throws: SasUrlClientError.self) {
			try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		}
	}

	@Test("401 response throws .unauthorized")
	func unauthorizedThrows() async throws {
		MockURLProtocol.requestHandler = { _ in
			makeJSONResponse(statusCode: 401, body: [:])
		}
		await #expect(throws: SasUrlClientError.unauthorized) {
			try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		}
	}

	@Test("415 response throws .unsupportedMediaType")
	func unsupportedMediaTypeThrows() async throws {
		MockURLProtocol.requestHandler = { _ in
			makeJSONResponse(statusCode: 415, body: [:])
		}
		await #expect(throws: SasUrlClientError.unsupportedMediaType) {
			try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		}
	}

	@Test("500 response throws .serverError with status code")
	func serverErrorThrows() async throws {
		MockURLProtocol.requestHandler = { _ in
			makeJSONResponse(statusCode: 500, body: [:])
		}
		await #expect(throws: SasUrlClientError.serverError(500)) {
			try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
		}
	}

	@Test("network failure throws .connectionError")
	func networkFailureThrowsConnectionError() async throws {
		MockURLProtocol.requestHandler = { _ in
			throw URLError(.notConnectedToInternet)
		}
		do {
			_ = try await makeClient().fetchSasUrl(for: makeSasUrlRequest())
			Issue.record("Expected connectionError to be thrown")
		} catch let error as SasUrlClientError {
			guard case .connectionError = error else {
				Issue.record("Expected .connectionError, got \(error)")
				return
			}
		}
	}
}
