// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Foundation

// MARK: - Request / Response

struct SasUrlRequest: Codable {
	let contentType: String
	let fileSizeBytes: Int64
}

struct SasUrlResponse: Decodable {
	let uploadUrl: String
	let expiresAt: String
}

// MARK: - Errors

enum SasUrlClientError: Error, Equatable {
	case invalidRequest(String)
	case unauthorized
	case unsupportedMediaType
	case serverError(Int)
	case connectionError(Error)
	case invalidResponse

	static func == (lhs: SasUrlClientError, rhs: SasUrlClientError) -> Bool {
		switch (lhs, rhs) {
		case (.invalidRequest(let l), .invalidRequest(let r)):
			return l == r
		case (.unauthorized, .unauthorized):
			return true
		case (.unsupportedMediaType, .unsupportedMediaType):
			return true
		case (.serverError(let l), .serverError(let r)):
			return l == r
		case (.connectionError, .connectionError):
			return true
		case (.invalidResponse, .invalidResponse):
			return true
		default:
			return false
		}
	}
}

// MARK: - Protocol

protocol SasUrlFetching: AnyObject {
	func fetchSasUrl(for request: SasUrlRequest) async throws -> SasUrlResponse
}

// MARK: - Client

final class SasUrlClient: SasUrlFetching {
	private let baseURL: URL
	private let apiKey: String
	private let urlSession: URLSession

	init(baseURL: URL, apiKey: String, urlSession: URLSession = .shared) {
		self.baseURL = baseURL
		self.apiKey = apiKey
		self.urlSession = urlSession
	}

	func fetchSasUrl(for request: SasUrlRequest) async throws -> SasUrlResponse {
		let url = baseURL.appending(path: "video")
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

		do {
			urlRequest.httpBody = try JSONEncoder().encode(request)
		} catch {
			throw SasUrlClientError.invalidRequest("Failed to encode request body: \(error)")
		}

		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await urlSession.data(for: urlRequest)
		} catch let urlError as URLError {
			throw SasUrlClientError.connectionError(urlError)
		} catch {
			throw SasUrlClientError.connectionError(error)
		}

		guard let httpResponse = response as? HTTPURLResponse else {
			throw SasUrlClientError.invalidResponse
		}

		switch httpResponse.statusCode {
		case 200:
			do {
				return try JSONDecoder().decode(SasUrlResponse.self, from: data)
			} catch {
				throw SasUrlClientError.invalidResponse
			}
		case 400:
			let message = String(data: data, encoding: .utf8) ?? "Bad request"
			throw SasUrlClientError.invalidRequest(message)
		case 401:
			throw SasUrlClientError.unauthorized
		case 415:
			throw SasUrlClientError.unsupportedMediaType
		default:
			throw SasUrlClientError.serverError(httpResponse.statusCode)
		}
	}
}
