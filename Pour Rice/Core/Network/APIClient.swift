//
//  APIClient.swift
//  Pour Rice
//
//  Core network client for all API communication.
//  Handles request building, header injection, authentication, and response parsing.
//

import Foundation

/// Protocol defining the API client interface for network requests.
/// Allows for easy mocking and testing of network layer.
/// Conforms to Sendable for safe concurrent access across actors.
protocol APIClient: Sendable {
    /// Executes an API request and decodes the response.
    /// Generic method supporting any Decodable response type.
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

/// Default implementation of APIClient using URLSession.
/// Automatically injects required headers (API passcode, auth token) and handles authentication.
/// Runs on the main actor for safe SwiftUI state updates.
@MainActor
final class DefaultAPIClient: APIClient {

    // MARK: - Properties

    /// URLSession instance for network requests.
    /// Can be replaced with custom session for testing or custom configurations.
    private let session: URLSession

    /// Auth service for retrieving Firebase ID tokens.
    /// Optional - nil for unauthenticated requests (e.g., public restaurant listings).
    private let authService: AuthService?

    // MARK: - Initialisation

    /// Creates a new API client instance.
    /// - Parameters:
    ///   - session: URLSession to use (defaults to .shared for production)
    ///   - authService: Auth service for token retrieval (optional, required for authenticated endpoints)
    init(session: URLSession = .shared, authService: AuthService? = nil) {
        self.session = session
        self.authService = authService
    }

    // MARK: - API Client Protocol

    /// Executes an API request with automatic header injection.
    /// Builds URL, injects headers (API passcode + auth token), executes request, validates response, and decodes JSON.
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - responseType: Expected response type (e.g., RestaurantListResponse.self)
    /// - Returns: Decoded response object
    /// - Throws: APIError for network, authentication, or decoding failures
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        // Build the URL request with method, query params, and body
        var request = try buildRequest(for: endpoint)

        // Inject required headers (API passcode and optional auth token)
        try await injectHeaders(into: &request)

        // Execute the network request
        let (data, response) = try await session.data(for: request)

        // Validate HTTP response status code (2xx = success)
        try validateResponse(response)

        // Decode JSON response into expected type
        return try decodeResponse(data: data, responseType: responseType)
    }

    // MARK: - Private Methods

    /// Builds a URLRequest from an API endpoint.
    /// Constructs full URL, sets HTTP method, adds query parameters, and encodes request body.
    /// - Parameter endpoint: The endpoint to build a request for
    /// - Returns: Configured URLRequest ready for execution
    /// - Throws: APIError.invalidURL if URL construction fails
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        // Construct full URL from base URL and endpoint path
        guard let url = URL(string: Constants.API.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30 // 30-second timeout for slow networks

        // Add query parameters if present (e.g., ?lat=51.5&lng=-0.1&radius=5000)
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let urlWithQuery = components?.url else {
                throw APIError.invalidURL
            }
            request.url = urlWithQuery
        }

        // Add request body if present (for POST/PUT requests)
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: Constants.API.Headers.contentType)
        }

        return request
    }

    /// Injects required headers into the request.
    /// Always adds API passcode header for backend authentication.
    /// Conditionally adds Firebase ID token for user-authenticated requests.
    /// - Parameter request: The request to inject headers into (passed as inout for modification)
    /// - Throws: APIError.unauthorized if authentication fails for protected endpoints
    private func injectHeaders(into request: inout URLRequest) async throws {
        // Always inject API passcode header (required by backend)
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
                // For public endpoints (e.g., restaurant listings), continue without the auth header
                print("Warning: Could not retrieve ID token: \(error.localizedDescription)")
            }
        }
    }

    /// Validates the HTTP response status code.
    /// Throws appropriate APIError for different failure scenarios.
    /// - Parameter response: The URLResponse to validate
    /// - Throws: APIError for non-2xx status codes (client errors, server errors, etc.)
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Success (OK, Created, Accepted, etc.) - continue processing
            break
        case 401:
            // Unauthorised - token expired or invalid
            throw APIError.unauthorized
        case 400...499:
            // Client error (Bad Request, Not Found, etc.)
            throw APIError.clientError(httpResponse.statusCode)
        case 500...599:
            // Server error (Internal Server Error, Service Unavailable, etc.)
            throw APIError.serverError(httpResponse.statusCode)
        default:
            // Unexpected status code
            throw APIError.invalidResponse
        }
    }

    /// Decodes the response data into the expected type.
    /// Uses ISO8601 date decoding strategy for API timestamp compatibility.
    /// Logs detailed error information for debugging decoding failures.
    /// - Parameters:
    ///   - data: Raw response data from server
    ///   - responseType: Expected response type (e.g., RestaurantListResponse.self)
    /// - Returns: Decoded response object
    /// - Throws: APIError.decodingError if decoding fails
    private func decodeResponse<T: Decodable>(data: Data, responseType: T.Type) throws -> T {
        let decoder = JSONDecoder()

        // Configure date decoding strategy to match backend ISO8601 format
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            // Log decoding error for debugging (helpful for development)
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            throw APIError.decodingError
        }
    }
}

// MARK: - HTTP Method

/// HTTP methods supported by the API client.
/// Raw values match standard HTTP method strings for URLRequest.
enum HTTPMethod: String {
    /// GET - Retrieve data (safe, idempotent)
    case get = "GET"

    /// POST - Create new resource
    case post = "POST"

    /// PUT - Update existing resource (full replacement)
    case put = "PUT"

    /// DELETE - Remove resource
    case delete = "DELETE"

    /// PATCH - Partially update resource
    case patch = "PATCH"
}
