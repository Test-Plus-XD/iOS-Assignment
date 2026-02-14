//
//  MenuService.swift
//  Pour Rice
//
//  Service for fetching restaurant menu items.
//  Provides filtering, categorisation, and searching functionality.
//

import Foundation

/// Service responsible for all menu-related operations.
/// Provides methods to fetch, filter, search, and sort menu items.
/// Runs on the main actor for safe SwiftUI state updates.
@MainActor
final class MenuService {

    // MARK: - Properties

    /// API client for network requests.
    /// Injected via dependency injection for testability.
    private let apiClient: APIClient

    // MARK: - Initialisation

    /// Creates a new menu service instance.
    /// - Parameter apiClient: API client for network requests
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Fetch Menu Items

    /// Fetches menu items for a specific restaurant.
    /// Makes network request to backend API and returns parsed menu data.
    /// - Parameters:
    ///   - restaurantId: Unique restaurant identifier
    ///   - limit: Maximum number of items to return (optional)
    /// - Returns: Array of menu items with bilingual names and descriptions
    /// - Throws: APIError for network or decoding failures
    func fetchMenuItems(restaurantId: String, limit: Int? = nil) async throws -> [Menu] {

        print("🔍 Fetching menu items for restaurant: \(restaurantId)")

        // Build endpoint with query parameters
        let endpoint = APIEndpoint.fetchMenuItems(restaurantId: restaurantId, limit: limit)

        // Execute network request and decode JSON response
        let response = try await apiClient.request(
            endpoint,
            responseType: MenuItemListResponse.self
        )

        print("✅ Fetched \(response.menuItems.count) menu items")

        return response.menuItems
    }

    // MARK: - Menu Filtering

    /// Filters menu items by category.
    /// Returns only items matching the specified category (e.g., mains, desserts).
    /// - Parameters:
    ///   - items: Array of menu items to filter
    ///   - category: Category to filter by
    /// - Returns: Filtered array of menu items in the specified category
    func filterByCategory(_ items: [Menu], category: MenuCategory) -> [Menu] {
        return items.filter { $0.category == category }
    }

    /// Groups menu items by category.
    /// Creates a dictionary for sectioned list views in SwiftUI.
    /// - Parameter items: Array of menu items to group
    /// - Returns: Dictionary mapping category to array of items
    func groupByCategory(_ items: [Menu]) -> [MenuCategory: [Menu]] {
        var grouped: [MenuCategory: [Menu]] = [:]

        // Iterate through items and append to appropriate category bucket
        for item in items {
            grouped[item.category, default: []].append(item)
        }

        return grouped
    }

    /// Filters menu items by availability.
    /// Useful for hiding out-of-stock or unavailable items from customers.
    /// - Parameters:
    ///   - items: Array of menu items to filter
    ///   - availableOnly: If true, returns only available items (defaults to true)
    /// - Returns: Filtered array of menu items
    func filterByAvailability(_ items: [Menu], availableOnly: Bool = true) -> [Menu] {
        guard availableOnly else { return items }
        return items.filter { $0.isAvailable }
    }

    /// Filters menu items by dietary restrictions.
    /// Returns items that match ALL specified dietary tags (e.g., vegan AND gluten-free).
    /// Uses allSatisfy to ensure strict dietary requirement matching.
    /// - Parameters:
    ///   - items: Array of menu items to filter
    ///   - dietaryTags: Array of dietary tags to match (e.g., [.vegan, .glutenFree])
    /// - Returns: Items that contain all specified dietary tags
    func filterByDietaryInfo(_ items: [Menu], dietaryTags: [DietaryTag]) -> [Menu] {
        guard !dietaryTags.isEmpty else { return items }

        return items.filter { item in
            // Check that the item contains ALL requested dietary tags
            dietaryTags.allSatisfy { tag in
                item.dietaryInfo.contains(tag)
            }
        }
    }

    /// Searches menu items by name or description.
    /// Case-insensitive search across both English and Traditional Chinese text.
    /// Searches both name and description fields for maximum coverage.
    /// - Parameters:
    ///   - items: Array of menu items to search
    ///   - query: Search query string (supports English and Chinese)
    /// - Returns: Items matching the search query
    func search(_ items: [Menu], query: String) -> [Menu] {
        guard !query.isEmpty else { return items }

        // Prepare lowercase query for case-insensitive English matching
        let lowercasedQuery = query.lowercased()

        return items.filter { item in
            // Search across English (case-insensitive) and Chinese (case-sensitive) fields
            item.name.en.lowercased().contains(lowercasedQuery) ||
            item.name.tc.contains(query) ||
            item.description.en.lowercased().contains(lowercasedQuery) ||
            item.description.tc.contains(query)
        }
    }

    // MARK: - Sorting

    /// Sorts menu items by price.
    /// Useful for displaying budget-friendly options or premium items first.
    /// - Parameters:
    ///   - items: Array of menu items to sort
    ///   - ascending: If true, sorts low to high (cheapest first); if false, sorts high to low
    /// - Returns: Sorted array of menu items
    func sortByPrice(_ items: [Menu], ascending: Bool = true) -> [Menu] {
        return items.sorted { ascending ? $0.price < $1.price : $0.price > $1.price }
    }

    /// Sorts menu items by name (English alphabetically).
    /// Uses localised case-insensitive comparison for proper alphabetical ordering.
    /// Sorts by English name for consistency in the app's primary language.
    /// - Parameter items: Array of menu items to sort
    /// - Returns: Sorted array of menu items in alphabetical order
    func sortByName(_ items: [Menu]) -> [Menu] {
        return items.sorted { $0.name.en.localizedCaseInsensitiveCompare($1.name.en) == .orderedAscending }
    }

    // MARK: - Statistics

    /// Calculates price range for a set of menu items.
    /// Useful for displaying "£10-£25" price indicators in UI.
    /// - Parameter items: Array of menu items to analyse
    /// - Returns: Tuple containing minimum and maximum prices, or nil if empty
    func priceRange(for items: [Menu]) -> (min: Double, max: Double)? {
        guard !items.isEmpty else { return nil }

        // Extract all prices and find min/max values
        let prices = items.map { $0.price }
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
            return nil
        }

        return (minPrice, maxPrice)
    }

    /// Calculates average price for a set of menu items.
    /// Useful for showing expected spending or budget estimates.
    /// - Parameter items: Array of menu items to analyse
    /// - Returns: Average price or nil if empty
    func averagePrice(for items: [Menu]) -> Double? {
        guard !items.isEmpty else { return nil }

        // Sum all prices and divide by count
        let total = items.reduce(0.0) { $0 + $1.price }
        return total / Double(items.count)
    }
}
