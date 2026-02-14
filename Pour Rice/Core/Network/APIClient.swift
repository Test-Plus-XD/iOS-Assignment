//
//  APIClient.swift
//  Pour Rice
//
//  Core network client for all API communication
//  Handles request building, header injection, and response parsing
//

import Foundation

/// Protocol defining the API client interface for network requests
/// Allows for easy mocking and testing of network layer
protocol APIClient: Sendable {
    /// Executes an API request and decodes the response
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - responseType: The expected response type to decode
    /// - Returns: Decoded response object
    /// - Throws: APIError for network or decoding failures
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T
}

/// Default implementation of APIClient using URLSession
/// Automatically injects required headers and handles authentication
@MainActor
final class DefaultAPIClient: APIClient {

    // MARK: - Properties

    /// URLSession instance for network requests
    private let session: URLSession

    /// Auth service for retrieving Firebase ID tokens
    private let authService: AuthService?

    // MARK: - Initialisation

    /// Creates a new API client instance
    /// - Parameters:
    ///   - session: URLSession to use (defaults to .shared)
    ///   - authService: Auth service for token retrieval (optional)
    init(session: URLSession = .shared, authService: AuthService? = nil) {
        self.session = session
        self.authService = authService
    }

    // MARK: - API Client Protocol

    /// Executes an API request with automatic header injection
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - responseType: Expected response type
    /// - Returns: Decoded response object
    /// - Throws: APIError for failures
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        // Build the URL request
        var request = try buildRequest(for: endpoint)

        // Inject required headers
        try await injectHeaders(into: &request)

        // Execute the request
        let (data, response) = try await session.data(for: request)

        // Validate HTTP response
        try validateResponse(response)

        // Decode and return the result
        return try decodeResponse(data: data, responseType: responseType)
    }

    // MARK: - Private Methods

    /// Builds a URLRequest from an API endpoint
    /// - Parameter endpoint: The endpoint to build a request for
    /// - Returns: Configured URLRequest
    /// - Throws: APIError.invalidURL if URL construction fails
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        // Construct full URL from base URL and endpoint path
        guard let url = URL(string: Constants.API.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30

        // Add query parameters if present
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let urlWithQuery = components?.url else {
                throw APIError.invalidURL
            }
            request.url = urlWithQuery
        }

        // Add request body if present
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: Constants.API.Headers.contentType)
        }

        return request
    }

    /// Injects required headers into the request
    /// - Parameter request: The request to inject headers into
    /// - Throws: APIError.unauthorized if authentication fails
    private func injectHeaders(into request: inout URLRequest) async throws {
        // Always inject API passcode header
        request.setValue(
            Constants.API.passcode,
            forHTTPHeaderField: Constants.API.Headers.apiPasscode
        )

        // Inject Firebase ID token for authenticated requests if auth service is available
        if let authService = authService {
            do {
                let idToken = try await authService.getIDToken()
                request.setValue(
                    "Bearer \(idToken)",
                    forHTTPHeaderField: Constants.API.Headers.authorization
                )
            } catch {
                // Only throw if the endpoint requires authentication
                // For public endpoints, continue without the auth header
                print("Warning: Could not retrieve ID token: \(error.localizedDescription)")
            }
        }
    }

    /// Validates the HTTP response status code
    /// - Parameter response: The URLResponse to validate
    /// - Throws: APIError for non-2xx status codes
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Success - continue
            break
        case 401:
            throw APIError.unauthorized
        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }

    /// Decodes the response data into the expected type
    /// - Parameters:
    ///   - data: Raw response data
    ///   - responseType: Expected response type
    /// - Returns: Decoded response object
    /// - Throws: APIError.decodingError if decoding fails
    private func decodeResponse<T: Decodable>(data: Data, responseType: T.Type) throws -> T {
        let decoder = JSONDecoder()

        // Configure date decoding strategy
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            // Log decoding error for debugging
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            throw APIError.decodingError
        }
    }
}

// MARK: - HTTP Method

/// HTTP methods supported by the API client
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
