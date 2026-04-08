//
//  QRDataHandler.swift
//  Pour Rice
//
//  Shared data-handling layer for QR payload processing.
//  It composes detection + API fetch so feature flow stays consistent across
//  iOS live camera scanning and macOS image/manual testing paths.
//

import Foundation

// MARK: - Data Handler

/// Coordinates the full QR data flow after a payload has been decoded.
///
/// Responsibilities:
/// 1. Validate the payload format using `QRPayloadDetector`
/// 2. Fetch the associated restaurant using a caller-injected fetch closure
///
/// This component is intentionally UI-independent, so it can be reused from
/// ViewModels, command tools, or future background workers.
struct QRDataHandler {

    /// Payload validator for deep-link parsing.
    private let detector: QRPayloadDetector

    /// Async fetch function injected from the service layer.
    private let fetchRestaurant: @Sendable (_ restaurantId: String) async throws -> Restaurant

    /// Creates a handler with injectable dependencies.
    ///
    /// - Parameters:
    ///   - detector: QR payload validator. Defaults to production implementation.
    ///   - fetchRestaurant: Async restaurant loader from service layer.
    init(
        detector: QRPayloadDetector = QRPayloadDetector(),
        fetchRestaurant: @escaping @Sendable (_ restaurantId: String) async throws -> Restaurant
    ) {
        self.detector = detector
        self.fetchRestaurant = fetchRestaurant
    }

    /// Executes the shared QR logic flow for a single payload string.
    ///
    /// - Parameter rawValue: Raw string decoded from a QR code.
    /// - Returns: The fetched `Restaurant` associated with the QR payload.
    /// - Throws: `QRDetectionError` for validation failures, or service errors for fetch failures.
    func handlePayload(_ rawValue: String) async throws -> Restaurant {
        let detection = try detector.detect(from: rawValue)
        return try await fetchRestaurant(detection.restaurantId)
    }
}
