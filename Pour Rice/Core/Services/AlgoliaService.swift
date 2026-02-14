//
//  AlgoliaService.swift
//  Pour Rice
//
//  Algolia search service for restaurant discovery
//  Provides fast, typo-tolerant search with filtering and geolocation
//

import Foundation
import AlgoliaSearchClient

/// Service responsible for Algolia-powered restaurant search
/// Provides instant search results with location-based ranking and filtering
@MainActor
final class AlgoliaService {

    // MARK: - Properties

    /// Algolia search client instance
    private let client: SearchClient

    /// Algolia index containing restaurant data
    private let index: Index

    // MARK: - Initialisation

    /// Creates a new Algolia search service instance
    /// Initialises search client with application credentials
    init() {
        // Initialise Algolia client with app ID and search-only API key
        self.client = SearchClient(
            appID: ApplicationID(rawValue: Constants.Algolia.applicationID),
            apiKey: APIKey(rawValue: Constants.Algolia.searchAPIKey)
        )

        // Get reference to restaurants index
        self.index = client.index(withName: IndexName(rawValue: Constants.Algolia.indexName))

        print("✅ Algolia search client initialised")
    }

    // MARK: - Search

    /// Performs a text search for restaurants with optional filters and location
    /// - Parameters:
    ///   - query: Search query string (restaurant name, cuisine, etc.)
    ///   - filters: Search filters for cuisine, price range, etc.
    ///   - location: Optional user location for geospatial ranking
    /// - Returns: Array of matching restaurants sorted by relevance
    /// - Throws: Algolia search errors
    func search(
        query: String,
        filters: SearchFilters,
        location: (lat: Double, lng: Double)? = nil
    ) async throws -> [Restaurant] {

        print("🔍 Algolia search: '\(query)' with filters: \(filters)")

        // Create search query
        var searchQuery = Query(query)

        // Configure search parameters
        searchQuery.hitsPerPage = Constants.Search.maxResults

        // Add location-based search if coordinates provided
        if let location = location {
            searchQuery.aroundLatLng = LatLng(
                lat: location.lat,
                lng: location.lng
            )
            searchQuery.aroundRadius = .explicit(Constants.Algolia.defaultSearchRadius)
            searchQuery.aroundPrecision = 100 // 100 metre precision
        }

        // Build filter string from filters
        var filterComponents: [String] = []

        // Add cuisine filters
        if !filters.cuisines.isEmpty {
            let cuisineFilter = filters.cuisines.map { "cuisine:\($0)" }.joined(separator: " OR ")
            filterComponents.append("(\(cuisineFilter))")
        }

        // Add price range filter
        if !filters.priceRanges.isEmpty {
            let priceFilter = filters.priceRanges.map { "priceRange:\($0)" }.joined(separator: " OR ")
            filterComponents.append("(\(priceFilter))")
        }

        // Add rating filter
        if let minRating = filters.minRating {
            filterComponents.append("rating >= \(minRating)")
        }

        // Combine all filters
        if !filterComponents.isEmpty {
            searchQuery.filters = filterComponents.joined(separator: " AND ")
        }

        // Execute search
        do {
            let response = try await index.search(query: searchQuery)

            // Decode hits to Restaurant objects
            let restaurants = try response.hits.compactMap { hit -> Restaurant? in
                guard let jsonData = try? JSONSerialization.data(withJSONObject: hit.object, options: []),
                      let restaurant = try? JSONDecoder().decode(Restaurant.self, from: jsonData) else {
                    return nil
                }
                return restaurant
            }

            print("✅ Algolia returned \(restaurants.count) results")

            return restaurants

        } catch {
            print("❌ Algolia search failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Browse All

    /// Fetches all restaurants without search query
    /// Useful for browsing and discovery screens
    /// - Parameters:
    ///   - filters: Optional filters to apply
    ///   - location: Optional user location for geospatial ranking
    /// - Returns: Array of restaurants
    /// - Throws: Algolia search errors
    func browseAll(
        filters: SearchFilters = SearchFilters(),
        location: (lat: Double, lng: Double)? = nil
    ) async throws -> [Restaurant] {
        // Perform search with empty query to get all results
        return try await search(query: "", filters: filters, location: location)
    }

    // MARK: - Autocomplete Suggestions

    /// Provides autocomplete suggestions for search queries
    /// Returns top matching cuisine types and restaurant names
    /// - Parameters:
    ///   - partialQuery: Partial search query string
    ///   - maxSuggestions: Maximum number of suggestions to return
    /// - Returns: Array of suggestion strings
    /// - Throws: Algolia search errors
    func autocomplete(partialQuery: String, maxSuggestions: Int = 5) async throws -> [String] {
        guard !partialQuery.isEmpty else { return [] }

        var searchQuery = Query(partialQuery)
        searchQuery.hitsPerPage = maxSuggestions
        searchQuery.attributesToRetrieve = ["name", "cuisine"]

        do {
            let response = try await index.search(query: searchQuery)

            // Extract unique suggestions from results
            var suggestions: Set<String> = []

            for hit in response.hits {
                if let name = hit.object["name"] as? String {
                    suggestions.insert(name)
                }
                if let cuisine = hit.object["cuisine"] as? String {
                    suggestions.insert(cuisine)
                }

                if suggestions.count >= maxSuggestions {
                    break
                }
            }

            return Array(suggestions.prefix(maxSuggestions))

        } catch {
            print("⚠️ Autocomplete failed: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Search Filters

/// Data structure for restaurant search filters
/// Used with AlgoliaService to refine search results
struct SearchFilters: Codable, Hashable {

    /// Selected cuisine types (e.g., "Italian", "Chinese", "Japanese")
    var cuisines: [String] = []

    /// Selected price ranges (e.g., "$", "$$", "$$$")
    var priceRanges: [String] = []

    /// Minimum rating filter (1.0 to 5.0)
    var minRating: Double?

    /// Dietary restrictions filter
    var dietaryRestrictions: [DietaryTag] = []

    /// Returns true if no filters are applied
    var isEmpty: Bool {
        return cuisines.isEmpty &&
               priceRanges.isEmpty &&
               minRating == nil &&
               dietaryRestrictions.isEmpty
    }

    /// Clears all filters
    mutating func clear() {
        cuisines = []
        priceRanges = []
        minRating = nil
        dietaryRestrictions = []
    }
}
