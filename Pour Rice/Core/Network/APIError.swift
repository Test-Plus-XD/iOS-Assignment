//
//  APIError.swift
//  Pour Rice
//
//  Error types for API network operations
//  Provides localised error messages for user-facing error displays
//

import Foundation

/// Enumeration of all possible API errors
/// Conforms to LocalizedError to provide user-friendly error messages
enum APIError: LocalizedError {

    // MARK: - Error Cases

    /// Network connectivity error
    case networkError(Error)

    /// Failed to decode API response
    case decodingError

    /// User is not authenticated or token expired
    case unauthorized

    /// Client-side error (4xx status codes)
    case clientError(Int)

    /// Server-side error (5xx status codes)
    case serverError(Int)

    /// Invalid or malformed response from server
    case invalidResponse

    /// Invalid URL construction
    case invalidURL

    /// Request timeout
    case timeout

    /// No internet connection available
    case noConnection

    // MARK: - LocalizedError Protocol

    /// Returns a localised description of the error for display to users
    /// Uses British English spelling throughout
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return String(localized: "error_network") + ": \(error.localizedDescription)"

        case .decodingError:
            return String(localized: "error_decoding")

        case .unauthorized:
            return String(localized: "error_unauthorised")

        case .clientError(let code):
            return String(localized: "error_client_\(code)")

        case .serverError(let code):
            return String(localized: "error_server_\(code)")

        case .invalidResponse:
            return String(localized: "error_invalid_response")

        case .invalidURL:
            return String(localized: "error_invalid_url")

        case .timeout:
            return String(localized: "error_timeout")

        case .noConnection:
            return String(localized: "error_no_connection")
        }
    }

    /// Returns a localised recovery suggestion for the error
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .noConnection:
            return String(localized: "error_recovery_network")

        case .unauthorized:
            return String(localized: "error_recovery_unauthorised")

        case .serverError:
            return String(localized: "error_recovery_server")

        case .timeout:
            return String(localized: "error_recovery_timeout")

        default:
            return String(localized: "error_recovery_default")
        }
    }

    /// Returns a concise failure reason for logging
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
    /// Logs the error with detailed information for debugging
    /// - Parameter context: Additional context information (e.g., endpoint, parameters)
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
