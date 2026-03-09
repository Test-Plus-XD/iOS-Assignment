//
//  AlgoliaService.swift
//  Pour Rice
//
//  Vercel-proxied Algolia search service for restaurant discovery.
//  Routes all search requests through the Vercel backend API so that
//  Algolia credentials never leave the server.
//
//  Endpoint: GET /API/Algolia/Restaurants
//  Base URL:  Constants.API.baseURL
//  Header:    x-api-passcode: PourRice
//

import Foundation

// MARK: - Algolia Service

/// Service for restaurant search via the Vercel Algolia proxy endpoint.
/// Replaces direct Algolia SDK calls — all search traffic now goes through
/// the backend so API keys remain server-side.
@MainActor
final class AlgoliaService {

    // MARK: - Private Response Models

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

    // MARK: - Initialisation

    /// Creates a new Algolia service instance (no SDK credentials required)
    init() {
        print("✅ Algolia search service initialised (Vercel proxy)")
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

    /// Fetches all restaurants with optional district/keyword filters.
    /// Performs a search with an empty query to return the full index.
    /// - Parameter filters: Optional filters to apply
    /// - Returns: Array of restaurants
    /// - Throws: Network or decoding errors
    func browseAll(filters: SearchFilters = SearchFilters()) async throws -> [Restaurant] {
        return try await search(query: "", filters: filters)
    }

    // MARK: - Private Helpers

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
