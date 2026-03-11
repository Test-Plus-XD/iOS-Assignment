//
//  RestaurantService.swift
//  Pour Rice
//
//  Service for fetching restaurant data from the backend API and performing
//  restaurant search via the Vercel Algolia proxy endpoint.
//  Implements caching to improve performance and reduce API calls.
//
//  Search endpoint: GET /API/Algolia/Restaurants
//  Base URL:        Constants.API.baseURL
//  Header:          x-api-passcode: PourRice
//

import Foundation

/// Service responsible for all restaurant data operations and search.
/// Provides fetch methods for nearby, featured, and individual restaurants,
/// plus Vercel-proxied Algolia search.
/// Implements in-memory caching to optimise performance.
@MainActor
final class RestaurantService {

    // MARK: - Private Search Response Models

    /// Top-level JSON wrapper returned by GET /API/Algolia/Restaurants
    private struct AlgoliaSearchResponse: Decodable {
        let hits: [AlgoliaHit]
        let nbHits: Int?
        let page: Int?
        let nbPages: Int?
    }

    /// A single search hit from the Algolia Restaurants index.
    /// Field names match the Firestore document keys exactly (capitalised).
    private struct AlgoliaHit: Decodable {
        let objectID: String
        let Name_EN: String?
        let Name_TC: String?
        let Address_EN: String?
        let Address_TC: String?
        let District_EN: String?
        let District_TC: String?
        let Keyword_EN: [String]?
        let Keyword_TC: [String]?
        let ImageUrl: String?
        let Seats: Int?
        let Latitude: Double?
        let Longitude: Double?

        // MARK: - Hit → Restaurant Mapping

        /// Maps this Algolia hit to a Restaurant model.
        /// Uses sensible defaults for fields not stored in the search index
        /// (e.g., openingHours, rating) — the detail endpoint provides those.
        func toRestaurant() -> Restaurant {
            let nameEN = Name_EN ?? ""
            let nameTC = Name_TC ?? nameEN
            let districtEN = District_EN ?? ""
            let districtTC = District_TC ?? districtEN
            let addrEN = Address_EN ?? ""
            let addrTC = Address_TC ?? addrEN

            // Pair Keyword_EN[i] with Keyword_TC[i] into BilingualText objects.
            // If TC array is shorter, fall back to the EN value.
            let kwEN = Keyword_EN ?? []
            let kwTC = Keyword_TC ?? []
            let keywords: [BilingualText] = kwEN.enumerated().map { idx, en in
                let tc = idx < kwTC.count ? kwTC[idx] : en
                return BilingualText(en: en, tc: tc)
            }

            // Algolia stores a single ImageUrl string; wrap in array to match model
            let imageURLs: [String] = ImageUrl.map { [$0] } ?? []

            return Restaurant(
                id: objectID,
                name: BilingualText(en: nameEN, tc: nameTC),
                description: BilingualText(uniform: ""),
                address: BilingualText(en: addrEN, tc: addrTC),
                district: BilingualText(en: districtEN, tc: districtTC),
                cuisine: BilingualText(uniform: ""),
                keywords: keywords,
                priceRange: "",
                rating: 0.0,
                reviewCount: 0,
                imageURLs: imageURLs,
                location: Location(latitude: Latitude ?? 0.0, longitude: Longitude ?? 0.0),
                openingHours: [],
                phoneNumber: "",
                email: nil,
                website: nil,
                seats: Seats ?? 0
            )
        }
    }

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

        print("✅ Restaurant service initialised (includes Vercel Algolia proxy)")
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
        radius: Double? = nil
    ) async throws -> [Restaurant] {
        let radius = radius ?? Constants.Location.defaultRadius

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

        print("🔍 Fetching featured restaurants (sampling 10 from full list)")

        let endpoint = APIEndpoint.fetchFeaturedRestaurants

        let response = try await apiClient.request(
            endpoint,
            responseType: RestaurantListResponse.self
        )

        // Randomly pick 10 restaurants from the full list as featured
        let featured = Array(response.restaurants.shuffled().prefix(10))

        print("✅ Sampled \(featured.count) featured restaurants from \(response.restaurants.count) total")

        return featured
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

    // MARK: - Search

    /// Searches for restaurants via the Vercel Algolia proxy endpoint.
    ///
    /// Translates `query` and `filters` into URL query parameters and
    /// decodes the Algolia `hits` array into Restaurant objects.
    ///
    /// - Parameters:
    ///   - query: Full-text search string (empty string returns all restaurants)
    ///   - filters: District and keyword filters to narrow results
    /// - Returns: Array of matching restaurants
    /// - Throws: URLError, DecodingError, or network errors
    func search(
        query: String,
        filters: SearchFilters
    ) async throws -> [Restaurant] {

        print("🔍 Vercel search: '\(query)' | districts: \(filters.districts) | keywords: \(filters.keywords)")

        // Build request URL with query parameters
        let request = try buildSearchRequest(query: query, filters: filters)

        // Execute network request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Validate HTTP status
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("❌ Vercel search error: HTTP \(http.statusCode)")
            throw URLError(.badServerResponse)
        }

        // Decode Algolia response and map hits to Restaurant objects
        let algoliaResponse = try JSONDecoder().decode(AlgoliaSearchResponse.self, from: data)
        let restaurants = algoliaResponse.hits.map { $0.toRestaurant() }

        print("✅ Vercel Algolia returned \(restaurants.count) / \(algoliaResponse.nbHits ?? 0) total results")

        return restaurants
    }

    // MARK: - Browse All

    func browseAll(filters: SearchFilters) async throws -> [Restaurant] {
        return try await search(query: "", filters: filters)
    }

    func browseAll() async throws -> [Restaurant] {
        return try await browseAll(filters: SearchFilters())
    }

    // MARK: - Private Search Helpers

    /// Builds a URLRequest for the Vercel Algolia search endpoint.
    private func buildSearchRequest(query: String, filters: SearchFilters) throws -> URLRequest {
        guard var components = URLComponents(
            string: Constants.API.baseURL + Constants.API.Endpoints.algoliaSearch
        ) else {
            throw URLError(.badURL)
        }

        // Assemble query parameters
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "0"),
            URLQueryItem(name: "hitsPerPage", value: String(Constants.Search.maxResults))
        ]

        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }

        // Districts → comma-separated list (e.g., "Central,Wan Chai")
        if !filters.districts.isEmpty {
            queryItems.append(URLQueryItem(name: "districts", value: filters.districts.joined(separator: ",")))
        }

        // Keywords → comma-separated list (e.g., "Vegan,Organic")
        if !filters.keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "keywords", value: filters.keywords.joined(separator: ",")))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(Constants.API.passcode, forHTTPHeaderField: Constants.API.Headers.apiPasscode)
        request.timeoutInterval = 30

        return request
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

// MARK: - Search Filters

/// Filters for the Vercel Algolia restaurant search endpoint.
/// Maps directly to the endpoint's `districts` and `keywords` query parameters.
///
/// Supported by GET /API/Algolia/Restaurants:
///   - `districts`: Comma-separated Hong Kong district names
///   - `keywords`: Comma-separated cuisine/dietary keyword tags
struct SearchFilters: Codable, Hashable {

    /// Selected Hong Kong districts to filter by (e.g., "Central", "Wan Chai")
    var districts: [String] = []

    /// Selected keyword tags to filter by (e.g., "Vegan", "Organic", "Dim Sum")
    var keywords: [String] = []

    /// Returns true if no filters are applied
    var isEmpty: Bool {
        return districts.isEmpty && keywords.isEmpty
    }

    /// Clears all active filters
    mutating func clear() {
        districts = []
        keywords = []
    }
}

