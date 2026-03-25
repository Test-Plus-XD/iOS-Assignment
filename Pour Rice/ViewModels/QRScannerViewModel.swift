//
//  QRScannerViewModel.swift
//  Pour Rice
//
//  ViewModel for the QR code scanner screen
//  Validates pourrice://menu/{restaurantId} URLs and fetches the corresponding restaurant
//
//  ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
//  Android equivalent: the callback logic inside QRScannerPage._handleQRCodeDetected()
//  (lib/pages/qr_scanner_page.dart). In Flutter this lives in the Widget itself;
//  here it is separated into a ViewModel following the iOS MVVM pattern.
//
//  Validation logic is identical to the Android app:
//    - scheme must be "pourrice"
//    - host must be "menu"
//    - first path segment is the restaurantId
//  =============================================================
//

import Foundation
import VisionKit    // Provides DataScannerViewController — used to check isSupported/isAvailable

// MARK: - Scanner State

/// Represents the lifecycle of a single QR scan attempt.
///
/// Using an enum with associated values (instead of multiple Bool flags)
/// makes illegal states unrepresentable — you cannot be both .loading and .idle.
///
/// FLUTTER EQUIVALENT:
/// A sealed class / discriminated union used for state management, e.g.:
///   sealed class ScannerState {}
///   class Idle extends ScannerState {}
///   class Loading extends ScannerState {}
///   class Success extends ScannerState { final Restaurant restaurant; }
///   class Error extends ScannerState { final String message; }
enum ScannerState {
    /// Waiting for the user to aim the camera at a QR code
    case idle
    /// A valid pourrice:// URL was detected; fetching restaurant details from the API
    case loading
    /// Restaurant fetched successfully — carries the full object so the view can navigate
    case success(Restaurant)
    /// Fetch failed or QR format was invalid — carries the localised error message
    case error(String)
}

// MARK: - QR Scanner View Model

/// Manages the state of the QR scanner UI.
///
/// Responsibilities:
///  1. Validate the raw scanned string against the pourrice://menu/{id} format
///  2. Fetch the restaurant from the API
///  3. Expose the result (success / error) so QRScannerView can navigate or toast
///
/// @MainActor ensures all property mutations happen on the main thread,
/// keeping SwiftUI state changes safe without manual DispatchQueue.main calls.
///
/// FLUTTER EQUIVALENT:
/// class QRScannerViewModel extends ChangeNotifier (or a Riverpod / BLoC class)
@MainActor @Observable
final class QRScannerViewModel {

    // MARK: - State

    /// Current scan lifecycle state — drives the UI (loading spinner, navigation, toast)
    var scannerState: ScannerState = .idle

    /// Prevents the DataScannerViewController delegate from processing a second barcode
    /// while an async restaurant fetch is already in flight.
    ///
    /// Without this guard, the delegate can fire multiple times in rapid succession
    /// for the same physical QR code, launching duplicate API requests.
    var isPaused = false

    /// Controls the device torch (flashlight) via AVCaptureDevice
    /// Updated in QRScannerView's updateUIViewController so the camera layer reacts
    var isTorchOn = false

    // MARK: - Toast

    /// Message text shown in the toast banner when an error occurs
    var toastMessage = ""
    /// Visual style of the toast (always .error for scanner errors)
    var toastStyle: ToastStyle = .error
    /// Triggers the .toast() modifier on QRScannerView when set to true
    var showToast = false

    // MARK: - Dependencies

    /// Restaurant service injected at init time.
    ///
    /// WHY NOT @Environment:
    /// ViewModels cannot access @Environment — they have no view hierarchy context.
    /// The caller (QRScannerView) reads services via @Environment and passes the
    /// relevant service into the ViewModel. This pattern is consistent with
    /// SearchViewModel(restaurantService:) and StoreViewModel.loadDashboard(storeService:…).
    private let restaurantService: RestaurantService

    // MARK: - Init

    /// - Parameter services: The shared Services container from @Environment(\.services).
    ///   Only restaurantService is extracted to keep dependencies explicit.
    init(services: Services) {
        self.restaurantService = services.restaurantService
    }

    // MARK: - QR Decode Handler

    /// Called by the DataScannerViewController delegate when a barcode is recognised.
    ///
    /// Flow:
    ///  1. Guard against concurrent calls via isPaused
    ///  2. Parse the raw string as a URL
    ///  3. Validate scheme == "pourrice" and host == "menu"
    ///  4. Extract restaurantId from the first path segment
    ///  5. Fetch restaurant; set scannerState = .success or show toast
    ///
    /// - Parameter rawValue: The payload string from the recognised QR barcode.
    func handleScannedString(_ rawValue: String) async {
        // isPaused prevents re-entry while an async fetch is still running.
        // DataScannerViewController can call the delegate multiple times per code.
        guard !isPaused else { return }
        isPaused = true     // Lock immediately — released on error, re-used on success (navigation replaces view)

        // Step 1 – Parse the raw QR payload as a URL
        guard let url = URL(string: rawValue) else {
            // The string is not a valid URL at all (e.g. a plain text QR)
            presentError("qr_error_invalid_format")
            isPaused = false
            return
        }

        // Step 2 – Validate scheme: must be "pourrice" (matches Android app)
        guard url.scheme == Constants.DeepLink.scheme else {
            presentError("qr_error_invalid_format")
            isPaused = false
            return
        }

        // Step 3 – Validate host: must be "menu" (pourrice://menu/...)
        guard url.host == Constants.DeepLink.menuHost else {
            presentError("qr_error_invalid_format")
            isPaused = false
            return
        }

        // Step 4 – Extract restaurantId from the first non-empty path segment.
        //
        // URL path components for "pourrice://menu/abc123":
        //   ["/" , "abc123"]   ← dropFirst() removes the leading "/"
        //
        // ANDROID EQUIVALENT:
        //   uri.pathSegments.first   (Dart Uri)
        guard let restaurantId = url.pathComponents.dropFirst().first, !restaurantId.isEmpty else {
            presentError("qr_error_invalid_format")
            isPaused = false
            return
        }

        // Step 5 – Fetch restaurant from the API (uses in-memory cache on repeat scans)
        scannerState = .loading

        do {
            // RestaurantService.fetchRestaurant(id:) maps to GET /API/Restaurants/{id}
            // No auth header required — public endpoint
            let restaurant = try await restaurantService.fetchRestaurant(id: restaurantId)
            // Success: set state so QRScannerView's .navigationDestination triggers navigation
            scannerState = .success(restaurant)
            // isPaused intentionally stays true — the view will be replaced by MenuView
        } catch {
            // API error (network failure, 404, etc.) — show toast and allow retry
            scannerState = .error(error.localizedDescription)
            presentError("qr_error_restaurant_not_found")
            isPaused = false    // Allow the user to scan again after the error toast
        }
    }

    /// Resets the ViewModel to idle so the user can attempt another scan.
    /// Called when the user dismisses an error or navigates back from MenuView.
    func reset() {
        scannerState = .idle
        isPaused = false
    }

    // MARK: - Private Helpers

    /// Shows an error toast using the shared toast system from View+Extensions.swift
    /// - Parameter key: Localisation key from Localizable.xcstrings (e.g. "qr_error_invalid_format")
    private func presentError(_ key: String) {
        // L10n.bundle resolves the correct .lproj bundle for the user's language preference
        // (same pattern used across all other ViewModels in the app)
        toastMessage = String(localized: String.LocalizationValue(key), bundle: L10n.bundle)
        toastStyle = .error
        showToast = true
    }
}
