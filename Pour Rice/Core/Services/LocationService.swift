//
//  LocationService.swift
//  Pour Rice
//
//  Core Location service for accessing user's geographical location
//  Handles location permissions and provides coordinates for nearby restaurant searches
//

import Foundation
import CoreLocation
import Observation

/// Service responsible for accessing and monitoring user location
/// Manages location permissions and provides coordinates for restaurant discovery
@MainActor
@Observable
final class LocationService: NSObject {

    // MARK: - Published Properties

    /// Current user location (nil if not available or permission denied)
    var currentLocation: CLLocation?

    /// Location authorization status
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Error that occurred during location access
    var error: Error?

    /// Loading state for location requests
    var isLoading = false

    // MARK: - Private Properties

    /// Core Location manager instance
    private let locationManager = CLLocationManager()

    /// Indicates if location updates are active
    private var isUpdatingLocation = false

    // MARK: - Initialisation

    /// Creates a new location service instance
    /// Configures location manager with appropriate accuracy settings
    override init() {
        super.init()

        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 metres

        // Get current authorization status
        authorizationStatus = locationManager.authorizationStatus

        print("✅ Location service initialised")
    }

    // MARK: - Permission Management

    /// Requests location permission from the user
    /// Shows system permission dialog if not yet determined
    func requestPermission() {
        print("📍 Requesting location permission")

        switch authorizationStatus {
        case .notDetermined:
            // First time - request when-in-use authorization
            locationManager.requestWhenInUseAuthorization()

        case .denied, .restricted:
            // Permission denied - inform user to enable in Settings
            error = LocationError.permissionDenied
            print("⚠️ Location permission denied or restricted")

        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized - start location updates
            startLocationUpdates()

        @unknown default:
            break
        }
    }

    // MARK: - Location Updates

    /// Starts receiving location updates
    /// Call this after permission is granted
    func startLocationUpdates() {
        guard !isUpdatingLocation else { return }

        print("📍 Starting location updates")

        isLoading = true
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    /// Stops receiving location updates
    /// Use this to conserve battery when location is not needed
    func stopLocationUpdates() {
        guard isUpdatingLocation else { return }

        print("📍 Stopping location updates")

        isLoading = false
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// Requests a single location update
    /// More battery-efficient than continuous updates
    func requestLocation() {
        print("📍 Requesting single location update")

        isLoading = true
        locationManager.requestLocation()
    }

    // MARK: - Permission Check

    /// Checks if location services are available and authorized
    /// - Returns: true if authorized and available, false otherwise
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse ||
               authorizationStatus == .authorizedAlways
    }

    /// Checks if location permission can be requested
    /// - Returns: true if permission can be requested, false if already determined
    var canRequestPermission: Bool {
        return authorizationStatus == .notDetermined
    }

    // MARK: - Distance Calculation

    /// Calculates distance in metres between two coordinates
    /// - Parameters:
    ///   - from: Starting location
    ///   - to: Destination location
    /// - Returns: Distance in metres
    static func distance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to)
    }

    /// Calculates distance in metres from current location to a point
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

    /// Called when location authorization status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        print("📍 Location authorization changed: \(authorizationStatus.description)")

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted - start updates
            startLocationUpdates()

        case .denied, .restricted:
            // Permission denied
            error = LocationError.permissionDenied
            stopLocationUpdates()

        case .notDetermined:
            // Still waiting for user decision
            break

        @unknown default:
            break
        }
    }

    /// Called when new location data is available
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update current location
        currentLocation = location
        isLoading = false

        print("✅ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("   Accuracy: ±\(location.horizontalAccuracy)m")
    }

    /// Called when location update fails
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error
        isLoading = false

        print("❌ Location update failed: \(error.localizedDescription)")

        // Handle specific error cases
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                self.error = LocationError.permissionDenied
                stopLocationUpdates()

            case .locationUnknown:
                // Location temporarily unavailable - keep trying
                print("⚠️ Location temporarily unknown, will retry")

            default:
                break
            }
        }
    }
}

// MARK: - Location Error

/// Errors that can occur during location access
enum LocationError: LocalizedError {

    /// User denied location permission
    case permissionDenied

    /// Location services disabled on device
    case servicesDisabled

    /// Failed to determine location
    case locationUnavailable

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
    /// Human-readable description of authorization status
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized Always"
        case .authorizedWhenInUse:
            return "Authorized When In Use"
        @unknown default:
            return "Unknown"
        }
    }
}
