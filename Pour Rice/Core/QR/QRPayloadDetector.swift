//
//  QRPayloadDetector.swift
//  Pour Rice
//
//  Shared QR detection logic that validates payloads and extracts restaurant IDs.
//  This file is platform-agnostic so it can be reused by iOS camera scanning,
//  macOS image-based testing, and any future background processing flows.
//

import Foundation

// MARK: - Detection Result

/// Canonical representation of a validated Pour Rice QR payload.
///
/// Once a payload is parsed into this type, downstream layers can rely on:
/// - scheme already validated (`pourrice`)
/// - host already validated (`menu`)
/// - `restaurantId` guaranteed to be non-empty
struct QRDetection {
    /// Restaurant identifier encoded in `pourrice://menu/{restaurantId}`.
    let restaurantId: String

    /// Reconstructed canonical deep-link URL string.
    ///
    /// We expose this mainly for diagnostics and future analytics usage.
    let canonicalURL: String
}

// MARK: - Detection Error

/// Platform-neutral QR validation errors.
///
/// The ViewModel maps these errors into localisation keys for user-facing toasts,
/// keeping presentation concerns outside this reusable logic layer.
enum QRDetectionError: Error {
    /// The payload could not be parsed as a valid URL.
    case invalidURL

    /// The URL does not match the app's required deep-link format.
    case invalidFormat
}

// MARK: - Detector

/// Validates QR payload strings and extracts the restaurant identifier.
///
/// ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
/// Think of this as a shared Dart/Kotlin utility that receives a raw string,
/// validates scheme + host, then returns a typed object with `restaurantId`.
/// =============================================================
struct QRPayloadDetector {

    /// Parses and validates a raw QR payload.
    ///
    /// - Parameter rawValue: The untrusted text decoded from a QR frame.
    /// - Returns: A validated `QRDetection` value containing the restaurant ID.
    /// - Throws: `QRDetectionError` when the payload is malformed.
    func detect(from rawValue: String) throws -> QRDetection {
        guard let url = URL(string: rawValue) else {
            throw QRDetectionError.invalidURL
        }

        guard url.scheme == Constants.DeepLink.scheme,
              url.host == Constants.DeepLink.menuHost
        else {
            throw QRDetectionError.invalidFormat
        }

        guard let restaurantId = url.pathComponents.dropFirst().first,
              !restaurantId.isEmpty
        else {
            throw QRDetectionError.invalidFormat
        }

        return QRDetection(
            restaurantId: restaurantId,
            canonicalURL: "\(Constants.DeepLink.scheme)://\(Constants.DeepLink.menuHost)/\(restaurantId)"
        )
    }
}
