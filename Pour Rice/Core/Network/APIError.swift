//
//  APIError.swift
//  Pour Rice
//
//  Error types for API network operations.
//  Provides localised error messages for user-facing error displays.
//

import Foundation

/// Enumeration of all possible API errors.
/// Conforms to LocalizedError to provide user-friendly error messages.
/// Covers network failures, authentication issues, and server errors.
enum APIError: LocalizedError {

    // MARK: - Error Cases

    /// Network connectivity error (DNS failure, connection refused, etc.).
    /// Associated value contains the underlying NSError for debugging.
    case networkError(Error)

    /// Failed to decode API response JSON.
    /// Indicates mismatch between expected and actual response structure.
    case decodingError

    /// User is not authenticated or token expired.
    /// Requires re-authentication via Firebase.
    case unauthorized

    /// Client-side error (4xx status codes).
    /// Associated value contains HTTP status code (e.g., 400, 404).
    case clientError(Int)

    /// Server-side error (5xx status codes).
    /// Associated value contains HTTP status code (e.g., 500, 503).
    case serverError(Int)

    /// Invalid or malformed response from server.
    /// Typically occurs when response is not HTTPURLResponse.
    case invalidResponse

    /// Invalid URL construction.
    /// Indicates programming error in endpoint path building.
    case invalidURL

    /// Request timeout (exceeded 30-second limit).
    /// Usually indicates slow network or server overload.
    case timeout

    /// No internet connection available.
    /// Device is offline or in aeroplane mode.
    case noConnection

    // MARK: - LocalizedError Protocol

    /// Returns a localised description of the error for display to users.
    /// Uses British English spelling throughout (e.g., "unauthorised").
    /// Loads strings from string catalogue for multi-language support.
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            // Include underlying error description for debugging
            return String(localized: "error_network") + ": \(error.localizedDescription)"

        case .decodingError:
            // JSON decoding failure
            return String(localized: "error_decoding")

        case .unauthorized:
            // 401 Unauthorised - token expired or invalid
            return String(localized: "error_unauthorised")

        case .clientError(let code):
            // 4xx errors (Bad Request, Not Found, etc.)
            return String(localized: "error_client_\(code)")

        case .serverError(let code):
            // 5xx errors (Internal Server Error, Service Unavailable, etc.)
            return String(localized: "error_server_\(code)")

        case .invalidResponse:
            // Non-HTTP response or unexpected format
            return String(localized: "error_invalid_response")

        case .invalidURL:
            // URL construction failed (programming error)
            return String(localized: "error_invalid_url")

        case .timeout:
            // Request exceeded 30-second timeout
            return String(localized: "error_timeout")

        case .noConnection:
            // Device offline or in aeroplane mode
            return String(localized: "error_no_connection")
        }
    }

    /// Returns a localised recovery suggestion for the error.
    /// Provides actionable guidance to help users resolve the issue.
    /// (e.g., "Check your internet connection", "Please sign in again").
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .noConnection:
            // Suggest checking Wi-Fi/cellular connection
            return String(localized: "error_recovery_network")

        case .unauthorized:
            // Suggest re-authenticating via sign-in screen
            return String(localized: "error_recovery_unauthorised")

        case .serverError:
            // Suggest trying again later (server issue)
            return String(localized: "error_recovery_server")

        case .timeout:
            // Suggest retrying the request
            return String(localized: "error_recovery_timeout")

        default:
            // Generic "try again" suggestion
            return String(localized: "error_recovery_default")
        }
    }

    /// Returns a concise failure reason for logging.
    /// Used for debugging and analytics tracking.
    /// Not displayed to users (uses errorDescription instead).
    var failureReason: String? {
        switch self {
        case .networkError:
            return "Network connection failed"

        case .decodingError:
            return "Failed to decode API response"

        case .unauthorized:
            return "Authentication required or token expired"

        case .clientError(let code):
            return "Client error with status code \(code)"

        case .serverError(let code):
            return "Server error with status code \(code)"

        case .invalidResponse:
            return "Received invalid response from server"

        case .invalidURL:
            return "Failed to construct valid URL"

        case .timeout:
            return "Request timed out"

        case .noConnection:
            return "No internet connection available"
        }
    }
}

// MARK: - Error Logging Extension

extension APIError {
    /// Logs the error with detailed information for debugging.
    /// Prints formatted error details to console for development troubleshooting.
    /// - Parameter context: Additional context information (e.g., endpoint name, request parameters)
    func log(context: String = "") {
        let errorInfo = """
        ═══════════════════════════════════════
        API Error Occurred
        ───────────────────────────────────────
        Error: \(self.failureReason ?? "Unknown error")
        Description: \(self.errorDescription ?? "No description")
        Context: \(context)
        ═══════════════════════════════════════
        """
        print(errorInfo)
    }
}
