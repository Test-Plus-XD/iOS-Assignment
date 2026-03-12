//
//  HomeViewModel.swift
//  Pour Rice
//
//  ViewModel for the home screen
//  Fetches featured and nearby restaurants in parallel using async/await
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is the equivalent of a ChangeNotifier or Riverpod provider in Flutter,
//  or a ViewModel extending LiveData in Android.
//
//  KEY DIFFERENCES FROM FLUTTER:
//  - @Observable replaces ChangeNotifier / notifyListeners()
//  - async let performs parallel fetches (equivalent to Future.wait())
//  - @MainActor ensures all UI updates happen on the main thread automatically
//  - No need to call setState() or notifyListeners() — @Observable handles this
//
//  FLUTTER EQUIVALENT:
//  class HomeViewModel extends ChangeNotifier {
//    List<Restaurant> featuredRestaurants = [];
//    List<Restaurant> nearbyRestaurants = [];
//    bool isLoading = false;
//    String? errorMessage;
//
//    Future<void> loadData() async { ... }
//  }
//  ============================================================================
//

import Foundation
import Observation   // @Observable macro framework
internal import _LocationEssentials

// MARK: - Home View Model

/// ViewModel for the HomeView
/// Manages featured and nearby restaurant data, loading states, and error handling
///
/// WHAT IS @Observable:
/// A macro that automatically makes properties observable by SwiftUI views.
/// Any view that reads a property from this class will rebuild when that property changes.
/// No need to use @Published or call notifyListeners().
///
/// WHAT IS @MainActor:
/// A global actor that ensures all code runs on the main (UI) thread.
/// Prevents race conditions when updating UI state from background tasks.
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Published State
    //
    // These properties are automatically observable by SwiftUI views.
    // When any of these change, views that read them will rebuild.

    /// Featured restaurants curated for the home screen carousel
    var featuredRestaurants: [Restaurant] = []

    /// Nearby restaurants based on the user's current location
    var nearbyRestaurants: [Restaurant] = []

    /// Whether a data load is currently in progress
    /// Used to show loading indicators in the view
    var isLoading = false

    /// Error message if the data load failed
    /// nil means no error occurred
    var errorMessage: String?

    /// Whether the initial data load has completed (even if empty)
    /// Prevents showing empty state before data has been fetched
    var hasLoadedOnce = false

    // MARK: - Dependencies

    /// Service for fetching restaurant data from the API
    private let restaurantService: RestaurantService

    /// Service for accessing the user's location
    private let locationService: LocationService

    // MARK: - Initialisation

    /// Creates a new HomeViewModel with required service dependencies
    /// - Parameters:
    ///   - restaurantService: Service for restaurant API calls
    ///   - locationService: Service for the device's location
    init(restaurantService: RestaurantService, locationService: LocationService) {
        self.restaurantService = restaurantService
        self.locationService = locationService
    }

    // MARK: - Data Loading

    /// Loads nearby restaurants and derives featured as a random sample.
    ///
    /// FLUTTER EQUIVALENT:
    /// final nearby = await restaurantService.fetchNearbyRestaurants(lat, lng);
    /// featuredRestaurants = (nearby..shuffle()).take(5);
    func loadData() async {
        // Don't start another load if already loading
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Determine coordinates for nearby search
            // Use current location if available, otherwise default to central Hong Kong
            let latitude = locationService.currentLocation?.coordinate.latitude ?? 22.3193
            let longitude = locationService.currentLocation?.coordinate.longitude ?? 114.1694

            // Fetch nearby restaurants
            //
            // FLUTTER EQUIVALENT:
            // final nearby = await restaurantService.fetchNearbyRestaurants(lat, lng);
            let nearby = try await restaurantService.fetchNearbyRestaurants(
                latitude: latitude,
                longitude: longitude,
                radius: Constants.Location.defaultRadius
            )

            // Update state with fetched data, capped to the nearest N restaurants
            // @Observable automatically notifies views of these changes
            nearbyRestaurants = Array(nearby.prefix(Constants.Location.nearbyLimit))

            // Derive featured restaurants as a random sample from the nearby list
            // No separate API call needed — matches the Flutter reference app behaviour
            featuredRestaurants = Array(nearby.shuffled().prefix(5))

        } catch {
            // Store the error message for display in the view
            errorMessage = error.localizedDescription
            print("❌ HomeViewModel: Failed to load data — \(error.localizedDescription)")
        }

        // Always clear loading state, even if an error occurred
        isLoading = false
        hasLoadedOnce = true
    }

    /// Refreshes both restaurant lists (pull-to-refresh support)
    ///
    /// Called when the user pulls down on the list to refresh.
    /// Clears existing data before fetching to show fresh results.
    func refresh() async {
        // Clear existing data so UI shows loading state
        featuredRestaurants = []
        nearbyRestaurants = []
        hasLoadedOnce = false

        // Reload all data
        await loadData()
    }
}
