//
//  QRFrameProcessor.swift
//  Pour Rice
//
//  Shared frame-processing logic for extracting QR payloads from image data.
//  This allows macOS users (and simulator users) to test the same QR flow
//  by importing screenshots/photos of QR codes instead of using a live camera.
//

import Foundation
internal import CoreImage

// MARK: - Frame Processing Error

/// Errors thrown while extracting QR strings from frame/image data.
enum QRFrameProcessingError: LocalizedError {
    /// The raw binary data could not be interpreted as an image.
    case invalidImageData

    /// Core Image could not create the QR detector instance.
    case detectorInitializationFailed

    /// The image decoded correctly but no QR code payload was found.
    case noQRCodeDetected

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The selected file is not a valid image."
        case .detectorInitializationFailed:
            return "The QR detector could not be initialised."
        case .noQRCodeDetected:
            return "No QR code was detected in the selected image."
        }
    }
}

// MARK: - Processor Protocol

/// Abstraction for QR payload extraction from image bytes.
///
/// Keeping this behind a protocol allows easy replacement in tests
/// (for example, a fake processor that returns deterministic payloads).
protocol QRFrameProcessing {
    /// Extracts one or more decoded QR payload strings from image data.
    /// - Parameter imageData: Encoded image bytes (PNG/JPEG/etc.).
    /// - Returns: Ordered payload list as detected by Core Image.
    func extractPayloads(from imageData: Data) throws -> [String]
}

// MARK: - Core Image Implementation

/// Core Image implementation of `QRFrameProcessing`.
///
/// Uses `CIDetector` with `CIDetectorTypeQRCode`, which is available on both
/// iOS-family platforms and macOS, making it suitable for shared logic.
struct CoreImageQRFrameProcessor: QRFrameProcessing, Sendable {

    func extractPayloads(from imageData: Data) throws -> [String] {
        guard let ciImage = CIImage(data: imageData) else {
            throw QRFrameProcessingError.invalidImageData
        }

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )

        guard let detector else {
            throw QRFrameProcessingError.detectorInitializationFailed
        }

        let features = detector.features(in: ciImage)
        let payloads = features
            .compactMap { $0 as? CIQRCodeFeature }
            .compactMap(\.messageString)

        guard !payloads.isEmpty else {
            throw QRFrameProcessingError.noQRCodeDetected
        }

        return payloads
    }
}
