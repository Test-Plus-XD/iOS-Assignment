//
//  QRScannerViewModel.swift
//  Pour Rice
//
//  ViewModel for the QR code scanner screen.
//  Uses shared QR logic layers (detection, frame processing, data handling)
//  so camera-based iOS scanning and macOS testing follow the same rules.
//
//  ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
//  Android equivalent: the callback logic inside QRScannerPage._handleQRCodeDetected()
//  (lib/pages/qr_scanner_page.dart). In Flutter this often sits inside the widget,
//  but here it is decomposed into reusable layers + a thin ViewModel coordinator.
//  =============================================================
//

import Foundation

// MARK: - Scanner State

enum ScannerState {
    /// Waiting for the user to scan or import a QR code
    case idle
    /// A valid pourrice:// URL was detected; fetching restaurant details from the API
    case loading
    /// Restaurant fetched successfully — carries the full object so the view can navigate
    case success(Restaurant)
    /// Fetch failed or QR format was invalid — carries the localised error message
    case error(String)
}

// MARK: - QR Scanner View Model

@MainActor @Observable
final class QRScannerViewModel {

    // MARK: - State

    var scannerState: ScannerState = .idle

    /// Prevents concurrent processing while an async scan flow is in progress.
    var isPaused = false

    /// Controls the device torch on iOS camera path.
    var isTorchOn = false

    // MARK: - Toast

    var toastMessage = ""
    var toastStyle: ToastStyle = .error
    var showToast = false

    // MARK: - Dependencies

    private let frameProcessor: QRFrameProcessing
    private let dataHandler: QRDataHandler

    // MARK: - Init

    init(services: Services) {
        self.frameProcessor = CoreImageQRFrameProcessor()
        self.dataHandler = QRDataHandler { restaurantId in
            try await services.restaurantService.fetchRestaurant(id: restaurantId)
        }
    }

    // MARK: - Public API

    /// Handles a payload received from a live camera scanner callback.
    func handleScannedString(_ rawValue: String) async {
        await processPayload(rawValue)
    }

    /// Handles image bytes (PNG/JPEG/etc.) and runs shared frame processing.
    ///
    /// This is used by macOS/simulator fallback UI so users can test QR flow
    /// without a physical iPhone camera.
    func handleScannedImageData(_ imageData: Data) async {
        do {
            let payloads = try frameProcessor.extractPayloads(from: imageData)
            guard let firstPayload = payloads.first else {
                scannerState = .error(String(localized: "qr_error_invalid_format", bundle: L10n.bundle))
                presentError("qr_error_invalid_format")
                return
            }

            // Reuse the exact same payload-processing path as live camera scanning.
            await processPayload(firstPayload)
        } catch {
            scannerState = .error(error.localizedDescription)
            presentError("qr_error_invalid_format")
        }
    }

    /// Resets the scanner state so a fresh scan attempt can begin.
    func reset() {
        scannerState = .idle
        isPaused = false
    }

    // MARK: - Private Helpers

    /// Runs the common detection + fetch flow through the shared data handler.
    private func processPayload(_ rawValue: String) async {
        guard !isPaused else { return }
        isPaused = true
        scannerState = .loading

        do {
            let restaurant = try await dataHandler.handlePayload(rawValue)
            scannerState = .success(restaurant)
            // Keep paused=true intentionally until navigation completes.
        } catch let detectionError as QRDetectionError {
            scannerState = .error(detectionError.localizedDescription)
            presentError(localisationKey(for: detectionError))
            isPaused = false
        } catch {
            scannerState = .error(error.localizedDescription)
            presentError("qr_error_restaurant_not_found")
            isPaused = false
        }
    }

    /// Maps shared detection errors to localisation keys used in string catalogues.
    private func localisationKey(for error: QRDetectionError) -> String {
        switch error {
        case .invalidURL, .invalidFormat:
            return "qr_error_invalid_format"
        }
    }

    /// Shows a localised error toast using the shared toast system.
    private func presentError(_ key: String) {
        toastMessage = String(localized: String.LocalizationValue(key), bundle: L10n.bundle)
        toastStyle = .error
        showToast = true
    }
}
