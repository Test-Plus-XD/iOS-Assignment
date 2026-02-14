//
//  LocationService.swift
//  Pour Rice
//
//  Core Location service for accessing user's geographical location.
//  Handles location permissions and provides coordinates for nearby restaurant searches.
//

import Foundation
import CoreLocation
import Observation

/// Service responsible for accessing and monitoring user location.
/// Manages location permissions and provides coordinates for restaurant discovery.
/// Uses the @Observable macro for automatic SwiftUI state updates.
@MainActor
@Observable
final class LocationService: NSObject {

    // MARK: - Published Properties

    /// Current user location (nil if not available or permission denied).
    /// Updates automatically when new location data is received from Core Location.
    var currentLocation: CLLocation?

    /// Location authorisation status from the system.
    /// Changes when user grants or denies permission via system dialogue.
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Error that occurred during location access.
    /// Set when location updates fail or permissions are denied.
    var error: Error?

    /// Loading state for location requests.
    /// True whilst waiting for location data from the system.
    var isLoading = false

    // MARK: - Private Properties

    /// Core Location manager instance for accessing GPS hardware.
    /// Configured to provide location updates with 100-metre accuracy.
    private let locationManager = CLLocationManager()

    /// Indicates if location updates are currently active.
    /// Used to prevent duplicate update requests to the manager.
    private var isUpdatingLocation = false

    // MARK: - Initialisation

    /// Creates a new location service instance.
    /// Configures location manager with appropriate accuracy settings.
    /// Sets up delegate callbacks and initialises authorisation status.
    override init() {
        super.init()

        // Configure location manager with balanced accuracy (100m precision)
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 metres to conserve battery

        // Get current authorisation status from the system
        authorizationStatus = locationManager.authorizationStatus

        print("✅ Location service initialised")
    }

    // MARK: - Permission Management

    /// Requests location permission from the user.
    /// Shows system permission dialogue if not yet determined.
    /// Automatically begins location updates if already authorised.
    func requestPermission() {
        print("📍 Requesting location permission")

        switch authorizationStatus {
        case .notDetermined:
            // First time - request when-in-use authorisation via system dialogue
            locationManager.requestWhenInUseAuthorization()

        case .denied, .restricted:
            // Permission denied or restricted by parental controls - set error state
            error = LocationError.permissionDenied
            print("⚠️ Location permission denied or restricted")

        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorised - begin tracking immediately
            startLocationUpdates()

        @unknown default:
            // Handle future iOS authorisation states gracefully
            break
        }
    }

    // MARK: - Location Updates

    /// Starts receiving continuous location updates.
    /// Call this after permission is granted to begin tracking.
    /// Guards against duplicate activation to prevent multiple update streams.
    func startLocationUpdates() {
        guard !isUpdatingLocation else { return }

        print("📍 Starting location updates")

        isLoading = true
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    /// Stops receiving location updates.
    /// Use this to conserve battery when location is not needed.
    /// Clears loading state and prevents further updates.
    func stopLocationUpdates() {
        guard isUpdatingLocation else { return }

        print("📍 Stopping location updates")

        isLoading = false
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// Requests a single location update.
    /// More battery-efficient than continuous updates for one-time location checks.
    /// Ideal for initial restaurant searches or refresh operations.
    func requestLocation() {
        print("📍 Requesting single location update")

        isLoading = true
        locationManager.requestLocation()
    }

    // MARK: - Permission Check

    /// Checks if location services are available and authorised.
    /// - Returns: true if authorised (when in use or always), false otherwise
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse ||
               authorizationStatus == .authorizedAlways
    }

    /// Checks if location permission can be requested.
    /// - Returns: true if permission can be requested (not yet determined), false if already determined
    var canRequestPermission: Bool {
        return authorizationStatus == .notDetermined
    }

    // MARK: - Distance Calculation

    /// Calculates distance in metres between two coordinates.
    /// - Parameters:
    ///   - from: Starting location
    ///   - to: Destination location
    /// - Returns: Distance in metres (as the crow flies)
    static func distance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to)
    }

    /// Calculates distance in metres from current location to a point.
    /// Useful for determining restaurant proximity from user position.
    /// - Parameters:
    ///   - latitude: Destination latitude
    ///   - longitude: Destination longitude
    /// - Returns: Distance in metres or nil if current location unavailable
    func distanceFromCurrentLocation(latitude: Double, longitude: Double) -> Double? {
        guard let currentLocation = currentLocation else { return nil }

        let destination = CLLocation(latitude: latitude, longitude: longitude)
        return currentLocation.distance(from: destination)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    /// Called when location authorisation status changes.
    /// Responds to user granting or denying location permissions.
    /// Automatically starts updates when authorised or sets error when denied.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        print("📍 Location authorisation changed: \(authorizationStatus.description)")

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - begin location tracking
            startLocationUpdates()

        case .denied, .restricted:
            // Permission denied or restricted by device settings
            error = LocationError.permissionDenied
            stopLocationUpdates()

        case .notDetermined:
            // Still waiting for user decision - do nothing
            break

        @unknown default:
            // Handle future iOS authorisation states gracefully
            break
        }
    }

    /// Called when new location data is available from GPS.
    /// Updates the current location property and clears loading state.
    /// Takes the most recent location from the array for accuracy.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update current location state and clear loading flag
        currentLocation = location
        isLoading = false

        print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("   Accuracy: ±\(location.horizontalAccuracy)m")
    }

    /// Called when location update fails.
    /// Handles permission denials and temporary GPS unavailability.
    /// Sets appropriate error states for UI feedback.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error
        isLoading = false

        print("❌ Location update failed: \(error.localizedDescription)")

        // Handle specific Core Location error cases
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                // User explicitly denied permission - stop trying
                self.error = LocationError.permissionDenied
                stopLocationUpdates()

            case .locationUnknown:
                // Location temporarily unavailable (e.g., poor GPS signal) - keep trying
                print("⚠️ Location temporarily unknown, will retry")

            default:
                // Other errors (network issues, etc.) - let default handling occur
                break
            }
        }
    }
}

// MARK: - Location Error

/// Errors that can occur during location access.
/// Provides localised error messages and recovery suggestions for users.
enum LocationError: LocalizedError {

    /// User denied location permission in system settings
    case permissionDenied

    /// Location services disabled on device (Settings → Privacy → Location Services)
    case servicesDisabled

    /// Failed to determine location (GPS unavailable, poor signal, etc.)
    case locationUnavailable

    /// Localised error description for display to users.
    /// Uses string catalogue for multi-language support.
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "error_location_permission_denied")

        case .servicesDisabled:
            return String(localized: "error_location_services_disabled")

        case .locationUnavailable:
            return String(localized: "error_location_unavailable")
        }
    }

    /// Localised recovery suggestion to help users resolve the error.
    /// Provides actionable guidance (e.g., "Enable location in Settings").
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "error_recovery_location_permission")

        case .servicesDisabled:
            return String(localized: "error_recovery_location_services")

        case .locationUnavailable:
            return String(localized: "error_recovery_location_unavailable")
        }
    }
}

// MARK: - CLAuthorizationStatus Extension

extension CLAuthorizationStatus {
    /// Human-readable description of authorisation status for debugging.
    /// Converts system status codes into readable strings for logging.
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorised Always"
        case .authorizedWhenInUse:
            return "Authorised When In Use"
        @unknown default:
            return "Unknown"
        }
    }
}
