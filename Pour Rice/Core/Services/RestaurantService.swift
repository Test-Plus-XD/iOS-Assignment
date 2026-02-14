//
//  RestaurantService.swift
//  Pour Rice
//
//  Service for fetching restaurant data from the backend API
//  Implements caching to improve performance and reduce API calls
//

import Foundation

/// Service responsible for all restaurant data operations
/// Provides methods to fetch nearby restaurants, restaurant details, and featured listings
/// Implements in-memory caching to optimise performance
@MainActor
final class RestaurantService {

    // MARK: - Properties

    /// API client for network requests
    private let apiClient: APIClient

    /// In-memory cache for restaurant details
    /// Key: Restaurant ID, Value: Cached restaurant data
    private let cache = NSCache<NSString, CacheEntry>()

    // MARK: - Initialisation

    /// Creates a new restaurant service instance
    /// - Parameter apiClient: API client for network requests
    init(apiClient: APIClient) {
        self.apiClient = apiClient

        // Configure cache limits
        cache.countLimit = Constants.Cache.restaurantCacheLimit
    }

    // MARK: - Fetch Nearby Restaurants

    /// Fetches restaurants near a specific geographical location
    /// Results are sorted by distance from the provided coordinates
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    ///   - radius: Search radius in metres (default: 5000m)
    /// - Returns: Array of nearby restaurants
    /// - Throws: APIError for network or decoding failures
    func fetchNearbyRestaurants(
        latitude: Double,
        longitude: Double,
        radius: Double = Constants.Location.defaultRadius
    ) async throws -> [Restaurant] {

        print("🔍 Fetching nearby restaurants (lat: \(latitude), lng: \(longitude), radius: \(radius)m)")

        let endpoint = APIEndpoint.fetchNearbyRestaurants(
            lat: latitude,
            lng: longitude,
            radius: radius
        )

        let response = try await apiClient.request(
            endpoint,
            responseType: RestaurantListResponse.self
        )

        print("✅ Fetched \(response.restaurants.count) nearby restaurants")

        return response.restaurants
    }

    // MARK: - Fetch Featured Restaurants

    /// Fetches featured restaurants for the home screen
    /// Returns curated list of recommended restaurants
    /// - Returns: Array of featured restaurants
    /// - Throws: APIError for network or decoding failures
    func fetchFeaturedRestaurants() async throws -> [Restaurant] {

        print("🔍 Fetching featured restaurants")

        let endpoint = APIEndpoint.fetchFeaturedRestaurants

        let response = try await apiClient.request(
            endpoint,
            responseType: RestaurantListResponse.self
        )

        print("✅ Fetched \(response.restaurants.count) featured restaurants")

        return response.restaurants
    }

    // MARK: - Fetch Restaurant Detail

    /// Fetches detailed information for a specific restaurant
    /// Implements caching to reduce redundant API calls
    /// - Parameter id: Unique restaurant identifier
    /// - Returns: Complete restaurant details
    /// - Throws: APIError for network or decoding failures
    func fetchRestaurant(id: String) async throws -> Restaurant {

        // Check cache first for better performance
        if let cached = cache.object(forKey: id as NSString) {
            // Verify cache hasn't expired
            if cached.expirationDate > Date() {
                print("✅ Returning cached restaurant: \(id)")
                return cached.restaurant
            } else {
                // Remove expired entry
                cache.removeObject(forKey: id as NSString)
            }
        }

        print("🔍 Fetching restaurant details: \(id)")

        // Fetch from API
        let endpoint = APIEndpoint.fetchRestaurant(id: id)
        let restaurant = try await apiClient.request(endpoint, responseType: Restaurant.self)

        // Cache the result
        let cacheEntry = CacheEntry(restaurant: restaurant)
        cache.setObject(cacheEntry, forKey: id as NSString)

        print("✅ Fetched and cached restaurant: \(restaurant.name.en)")

        return restaurant
    }

    // MARK: - Cache Management

    /// Clears all cached restaurant data
    /// Useful for forcing data refresh or freeing memory
    func clearCache() {
        cache.removeAllObjects()
        print("🗑️ Restaurant cache cleared")
    }

    /// Removes a specific restaurant from the cache
    /// - Parameter id: Restaurant ID to remove from cache
    func removeCachedRestaurant(id: String) {
        cache.removeObject(forKey: id as NSString)
        print("🗑️ Removed restaurant from cache: \(id)")
    }
}

// MARK: - Cache Entry

/// Internal cache entry for storing restaurant data with expiration
private class CacheEntry {

    /// Cached restaurant data
    let restaurant: Restaurant

    /// Date when this cache entry expires
    let expirationDate: Date

    /// Creates a new cache entry with automatic expiration
    /// - Parameter restaurant: Restaurant to cache
    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        self.expirationDate = Date().addingTimeInterval(Constants.Cache.cacheExpirationInterval)
    }
}
