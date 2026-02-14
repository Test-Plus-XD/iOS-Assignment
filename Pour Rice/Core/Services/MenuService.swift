//
//  MenuService.swift
//  Pour Rice
//
//  Service for fetching restaurant menu items
//  Provides filtering and categorization functionality
//

import Foundation

/// Service responsible for all menu-related operations
/// Provides methods to fetch and filter menu items by category
@MainActor
final class MenuService {

    // MARK: - Properties

    /// API client for network requests
    private let apiClient: APIClient

    // MARK: - Initialisation

    /// Creates a new menu service instance
    /// - Parameter apiClient: API client for network requests
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch Menu Items

    /// Fetches menu items for a specific restaurant
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of items to return (optional)
    /// - Returns: Array of menu items
    /// - Throws: APIError for network or decoding failures
    func fetchMenuItems(restaurantId: String, limit: Int? = nil) async throws -> [MenuItem] {

        print("🔍 Fetching menu items for restaurant: \(restaurantId)")

        let endpoint = APIEndpoint.fetchMenuItems(restaurantId: restaurantId, limit: limit)

        let response = try await apiClient.request(
            endpoint,
            responseType: MenuItemListResponse.self
        )

        print("✅ Fetched \(response.menuItems.count) menu items")

        return response.menuItems
    }

    // MARK: - Menu Filtering

    /// Filters menu items by category
    /// - Parameters:
    ///   - items: Array of menu items to filter
    ///   - category: Category to filter by
    /// - Returns: Filtered array of menu items
    func filterByCategory(_ items: [MenuItem], category: MenuCategory) -> [MenuItem] {
        return items.filter { $0.category == category }
    }

    /// Groups menu items by category
    /// - Parameter items: Array of menu items to group
    /// - Returns: Dictionary mapping category to array of items
    func groupByCategory(_ items: [MenuItem]) -> [MenuCategory: [MenuItem]] {
        var grouped: [MenuCategory: [MenuItem]] = [:]

        for item in items {
            grouped[item.category, default: []].append(item)
        }

        return grouped
    }

    /// Filters menu items by availability
    /// - Parameters:
    ///   - items: Array of menu items to filter
    ///   - availableOnly: If true, returns only available items
    /// - Returns: Filtered array of menu items
    func filterByAvailability(_ items: [MenuItem], availableOnly: Bool = true) -> [MenuItem] {
        guard availableOnly else { return items }
        return items.filter { $0.isAvailable }
    }

    /// Filters menu items by dietary restrictions
    /// - Parameters:
    ///   - items: Array of menu items to filter
    ///   - dietaryTags: Array of dietary tags to match
    /// - Returns: Items that contain all specified dietary tags
    func filterByDietaryInfo(_ items: [MenuItem], dietaryTags: [DietaryTag]) -> [MenuItem] {
        guard !dietaryTags.isEmpty else { return items }

        return items.filter { item in
            dietaryTags.allSatisfy { tag in
                item.dietaryInfo.contains(tag)
            }
        }
    }

    /// Searches menu items by name or description
    /// Case-insensitive search across both English and Chinese text
    /// - Parameters:
    ///   - items: Array of menu items to search
    ///   - query: Search query string
    /// - Returns: Items matching the search query
    func search(_ items: [MenuItem], query: String) -> [MenuItem] {
        guard !query.isEmpty else { return items }

        let lowercasedQuery = query.lowercased()

        return items.filter { item in
            item.name.en.lowercased().contains(lowercasedQuery) ||
            item.name.tc.contains(query) ||
            item.description.en.lowercased().contains(lowercasedQuery) ||
            item.description.tc.contains(query)
        }
    }

    // MARK: - Sorting

    /// Sorts menu items by price
    /// - Parameters:
    ///   - items: Array of menu items to sort
    ///   - ascending: If true, sorts low to high; if false, sorts high to low
    /// - Returns: Sorted array of menu items
    func sortByPrice(_ items: [MenuItem], ascending: Bool = true) -> [MenuItem] {
        return items.sorted { ascending ? $0.price < $1.price : $0.price > $1.price }
    }

    /// Sorts menu items by name (English alphabetically)
    /// - Parameter items: Array of menu items to sort
    /// - Returns: Sorted array of menu items
    func sortByName(_ items: [MenuItem]) -> [MenuItem] {
        return items.sorted { $0.name.en.localizedCaseInsensitiveCompare($1.name.en) == .orderedAscending }
    }

    // MARK: - Statistics

    /// Calculates price range for a set of menu items
    /// - Parameter items: Array of menu items to analyse
    /// - Returns: Tuple containing minimum and maximum prices
    func priceRange(for items: [MenuItem]) -> (min: Double, max: Double)? {
        guard !items.isEmpty else { return nil }

        let prices = items.map { $0.price }
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
            return nil
        }

        return (minPrice, maxPrice)
    }

    /// Calculates average price for a set of menu items
    /// - Parameter items: Array of menu items to analyse
    /// - Returns: Average price or nil if empty
    func averagePrice(for items: [MenuItem]) -> Double? {
        guard !items.isEmpty else { return nil }

        let total = items.reduce(0.0) { $0 + $1.price }
        return total / Double(items.count)
    }
}
