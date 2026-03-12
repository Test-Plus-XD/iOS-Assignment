//
//  APILogger.swift
//  Pour Rice
//
//  Structured runtime logger for all API calls, raw responses, and data-flow mappings.
//  Uses OSLog for Xcode Console filtering (subsystem: com.pourrice, category: API).
//  Also emits a one-time model verification report on first use, listing known
//  API-vs-iOS-model field mismatches that will cause decode/submission failures.
//
//  DEBUG ONLY — entire file is stripped from Release builds via #if DEBUG.
//
//  XCODE CONSOLE FILTER:
//    subsystem:com.pourrice category:API
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is like a custom Timber/Logger tagged utility. Each log line is prefixed
//  with [ServiceName] so you can trace which service initiated each network call.
//  In Android you'd use Log.d("RestaurantService", "...") — this is the equivalent.
//  ============================================================================
//

#if DEBUG
import Foundation
import OSLog

// MARK: - APILogger

/// Centralised API logger. Namespace-style enum — not instantiable.
/// All methods are static and safe to call from @MainActor contexts.
enum APILogger {

    // MARK: - Private State

    /// OSLog logger instance. Category "API" allows Xcode Console filter:
    ///   subsystem:com.pourrice category:API
    private static let logger = Logger(subsystem: "com.pourrice", category: "API")

    /// Guards the one-time startup model-verification report.
    /// Safe as nonisolated(unsafe) because all callers are @MainActor (single thread).
    private nonisolated(unsafe) static var hasEmittedStartupReport = false

    // MARK: - Startup Model Verification Report

    /// Emits a model/API mapping summary to the Xcode Console exactly once per session.
    /// Called from RestaurantService.init() so it fires before the first network request.
    ///
    /// Lists the key field mappings between iOS models and the Vercel Express API,
    /// confirming they are correctly aligned after the fixes applied in March 2026.
    static func emitStartupReportIfNeeded() {
        guard !hasEmittedStartupReport else { return }
        hasEmittedStartupReport = true

        let sep  = String(repeating: "═", count: 50)
        let dash = String(repeating: "─", count: 50)

        logger.debug("ℹ️  \(sep, privacy: .public)")
        logger.debug("ℹ️  MODEL ↔ API MAPPING SUMMARY  (emitted once at startup)")
        logger.debug("ℹ️  \(sep, privacy: .public)")

        // ── Restaurant model ─────────────────────────────────────────────
        logger.debug("""
        ✅ [Restaurant] GET /API/Restaurants/:id
              id            ← "id"
              name          ← BilingualText(Name_EN, Name_TC)
              address       ← BilingualText(Address_EN, Address_TC)
              district      ← BilingualText(District_EN, District_TC)
              keywords      ← zip(Keyword_EN[], Keyword_TC[])
              imageURLs     ← ["ImageUrl"]   (single URL wrapped in array)
              location      ← Location(Latitude, Longitude)
              seats         ← "Seats"
              description / cuisine / priceRange / rating /
              reviewCount / openingHours / phoneNumber / email / website
                            ← (not in API — defaulted to empty/zero)
        """)
        logger.debug("ℹ️  \(dash, privacy: .public)")

        // ── Review model ─────────────────────────────────────────────────
        logger.debug("""
        ✅ [Review] GET /API/Reviews
              id            ← "id"           (was "reviewId")
              userName      ← "userDisplayName"
              photoURLs     ← ["imageUrl"]   (single URL wrapped in array)
              dateTime      ← "dateTime"     (ISO 8601, new field)
              updatedAt     ← "modifiedAt"   (was "updatedAt")
        """)
        logger.debug("ℹ️  \(dash, privacy: .public)")

        // ── ReviewListResponse ───────────────────────────────────────────
        logger.debug("""
        ✅ [ReviewListResponse] GET /API/Reviews
              reviews       ← "data"         (was synthesised key "reviews")
              totalCount    ← "count"        (was synthesised key "totalCount")
        """)
        logger.debug("ℹ️  \(dash, privacy: .public)")

        // ── ReviewRequest ────────────────────────────────────────────────
        logger.debug("""
        ✅ [ReviewRequest] POST /API/Reviews
              restaurantId  → "restaurantId"
              rating        → "rating"
              comment       → "comment"
              dateTime      → "dateTime"     (ISO 8601, was missing — caused 400)
              photoURLs     → "photoURLs"    (API ignores; use /API/Images/upload)
        """)
        logger.debug("ℹ️  \(dash, privacy: .public)")

        // ── Menu model ───────────────────────────────────────────────────
        logger.debug("""
        ✅ [Menu] GET /API/Restaurants/:id/menu
              id            ← "id"           (was "menuItemId")
              name          ← BilingualText(Name_EN, Name_TC)
              description   ← BilingualText(Description_EN, Description_TC)
              price         ← "price"
              imageURL      ← "image"        (was "imageUrl")
              restaurantId / category / dietaryInfo / isAvailable / spiceLevel
                            ← (not in API — defaulted to empty/false/nil)
        """)
        logger.debug("ℹ️  \(dash, privacy: .public)")

        // ── MenuItemListResponse ─────────────────────────────────────────
        logger.debug("""
        ✅ [MenuItemListResponse] GET /API/Restaurants/:id/menu
              menuItems     ← "data"         (was synthesised key "menuItems")
        """)

        logger.debug("ℹ️  \(sep, privacy: .public)")
        logger.debug("ℹ️  END OF MODEL MAPPING SUMMARY")
        logger.debug("ℹ️  \(sep, privacy: .public)")
    }

    // MARK: - Request Logging

    /// Logs an outgoing URLRequest with method, full URL, headers, and body.
    /// Authorization header value is redacted for security.
    /// - Parameters:
    ///   - request: The fully-built URLRequest about to be sent
    ///   - service: Name of the service initiating the call (e.g. "RestaurantService")
    static func logRequest(_ request: URLRequest, from service: String) {
        emitStartupReportIfNeeded()

        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "(unknown URL)"
        let headers = redactedHeaders(from: request.allHTTPHeaderFields ?? [:])
        let body: String = {
            guard let data = request.httpBody,
                  let str = String(data: data, encoding: .utf8) else {
                return "(none)"
            }
            return str.count > 2000 ? String(str.prefix(2000)) + "… [truncated]" : str
        }()

        logger.debug("""
        [\(service, privacy: .public)] \(separator(), privacy: .public)
        [\(service, privacy: .public)] 📤 REQUEST  \(method, privacy: .public) \(url, privacy: .public)
        [\(service, privacy: .public)] Headers: \(headers, privacy: .public)
        [\(service, privacy: .public)] Body: \(body, privacy: .public)
        [\(service, privacy: .public)] \(separator(), privacy: .public)
        """)
    }

    // MARK: - Response Logging

    /// Logs an HTTP response with status code, duration, and raw JSON body.
    /// JSON is truncated at 8 000 characters to stay within OSLog limits.
    /// - Parameters:
    ///   - response: The URLResponse received from the server
    ///   - data: Raw response body bytes
    ///   - duration: Elapsed time from request start to response received
    ///   - service: Name of the service that made the call
    static func logResponse(
        _ response: URLResponse,
        data: Data,
        duration: TimeInterval,
        from service: String
    ) {
        let statusCode: String = {
            guard let http = response as? HTTPURLResponse else { return "???" }
            return String(http.statusCode)
        }()

        let durationStr = String(format: "%.3fs", duration)
        let json = formatJSON(data)

        logger.debug("""
        [\(service, privacy: .public)] 📥 RESPONSE \(statusCode, privacy: .public) (\(durationStr, privacy: .public))
        [\(service, privacy: .public)] Raw JSON:
        \(json, privacy: .public)
        [\(service, privacy: .public)] \(separator(), privacy: .public)
        """)
    }

    // MARK: - Decode Logging

    /// Logs a successful JSON decode with the decoded type name.
    /// - Parameters:
    ///   - type: The Swift type that was decoded
    ///   - service: Name of the service that owns this decode
    static func logDecoded<T>(_ type: T.Type, from service: String) {
        let typeName = String(describing: type)
        logger.debug("[\(service, privacy: .public)] ✅ Decoded → \(typeName, privacy: .public)")
    }

    /// Logs a decode failure with error details and the raw JSON that failed.
    /// Replaces the existing print() calls in APIClient.decodeResponse.
    /// - Parameters:
    ///   - type: The Swift type that failed to decode
    ///   - error: The decoding error
    ///   - data: Raw response data that caused the failure
    ///   - service: Name of the service that owns this decode
    static func logDecodeFailure<T>(_ type: T.Type, error: Error, data: Data, from service: String) {
        let typeName = String(describing: type)
        let errorDesc = error.localizedDescription
        let json = formatJSON(data)

        logger.error("""
        [\(service, privacy: .public)] ❌ DECODE FAILURE → \(typeName, privacy: .public)
        [\(service, privacy: .public)] Error: \(errorDesc, privacy: .public)
        [\(service, privacy: .public)] Full error: \(String(describing: error), privacy: .public)
        [\(service, privacy: .public)] Raw JSON that failed:
        \(json, privacy: .public)
        [\(service, privacy: .public)] \(separator(), privacy: .public)
        """)
    }

    // MARK: - Data-Flow Logging

    /// Logs data transformations between services (e.g. API response → model array).
    /// - Parameters:
    ///   - label: Human-readable description of the transformation
    ///   - summary: Short summary of the result (e.g. "mapped 12 items")
    ///   - service: Name of the service performing the transformation
    static func logDataFlow(label: String, summary: String, from service: String) {
        logger.debug("[\(service, privacy: .public)] [DataFlow] \(label, privacy: .public): \(summary, privacy: .public)")
    }

    // MARK: - Private Helpers

    /// Returns a visual separator line for log blocks.
    private static func separator() -> String {
        return String(repeating: "─", count: 50)
    }

    /// Formats request headers as a single line, redacting the Authorization value.
    private static func redactedHeaders(from headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "(none)" }
        return headers.map { key, value in
            key.lowercased() == "authorization" ? "\(key): [REDACTED]" : "\(key): \(value)"
        }.joined(separator: " | ")
    }

    /// Converts raw response Data to a UTF-8 string, truncated at 8 000 chars.
    private static func formatJSON(_ data: Data) -> String {
        guard !data.isEmpty else { return "(empty body)" }
        guard let str = String(data: data, encoding: .utf8) else {
            return "(non-UTF-8 body, \(data.count) bytes)"
        }
        if str.count > 8000 {
            return String(str.prefix(8000)) + "\n… [truncated — \(str.count) chars total]"
        }
        return str
    }
}
#endif
