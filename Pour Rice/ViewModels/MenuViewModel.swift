//
//  MenuViewModel.swift
//  Pour Rice
//
//  ViewModel for the full menu screen
//  Fetches all menu items and provides client-side filtering and search
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  Equivalent to a Flutter ChangeNotifier or Riverpod StateNotifier.
//
//  KEY PATTERNS:
//  - @Observable replaces ChangeNotifier + notifyListeners()
//  - All menu items fetched once; filtering is done client-side (fast, offline)
//  - groupedMenu computed property builds a sectioned dictionary on-the-fly
//  - MenuService.groupByCategory() / filterByDietaryInfo() handle business logic
//  ============================================================================
//

import Foundation
import Observation

// MARK: - Menu View Model

/// ViewModel for the MenuView full-screen menu
/// Manages all menu items for one restaurant and provides filtering/search
@MainActor
@Observable
final class MenuViewModel {

    // MARK: - State

    /// All menu items fetched from the API for this restaurant
    var allItems: [Menu] = []

    /// Search query entered by the user
    var searchQuery: String = ""

    /// Currently selected dietary filters (empty = show all)
    var selectedDietaryFilters: Set<DietaryTag> = []

    /// Whether to show only currently available items
    var showAvailableOnly: Bool = false

    /// Whether data is loading
    var isLoading = false

    /// Error message if loading failed
    var errorMessage: String?

    // MARK: - Computed: Filtered Items

    /// Items after applying search query and dietary filters
    /// All filtering is done client-side on the fetched data
    ///
    /// PIPELINE:
    /// allItems → search filter → dietary filter → availability filter
    ///
    /// FLUTTER EQUIVALENT:
    /// List<MenuItem> get filteredItems {
    ///   var result = allItems;
    ///   if (searchQuery.isNotEmpty) result = result.where(...).toList();
    ///   // ... etc
    ///   return result;
    /// }
    var filteredItems: [Menu] {
        var result = allItems

        // Apply search query (bilingual — EN + TC)
        if !searchQuery.isEmpty {
            result = menuService.search(result, query: searchQuery)
        }

        // Apply dietary filters (all selected tags must match)
        if !selectedDietaryFilters.isEmpty {
            result = menuService.filterByDietaryInfo(result, dietaryTags: Array(selectedDietaryFilters))
        }

        // Optionally hide unavailable items
        if showAvailableOnly {
            result = menuService.filterByAvailability(result, availableOnly: true)
        }

        return result
    }

    /// Filtered items grouped by category for sectioned list display
    ///
    /// WHAT IS [MenuCategory: [Menu]]:
    /// A Dictionary where keys are MenuCategory enum cases and values are arrays of Menu items
    /// Similar to Map<MenuCategory, List<Menu>> in Dart/Kotlin
    ///
    /// ORDERED SECTIONS:
    /// We iterate MenuCategory.allCases to display sections in a consistent order
    /// (Appetiser → Main Course → Dessert → Beverage → Side)
    var groupedMenu: [(category: MenuCategory, items: [Menu])] {
        let grouped = menuService.groupByCategory(filteredItems)

        // Return in the canonical order from MenuCategory.allCases
        // This ensures Appetisers always come first, Sides always last
        return MenuCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category: category, items: items)
        }
    }

    /// True if any filter or search is active
    var hasActiveFilters: Bool {
        !searchQuery.isEmpty || !selectedDietaryFilters.isEmpty || showAvailableOnly
    }

    // MARK: - Dependencies

    private let menuService: MenuService

    // MARK: - Initialisation

    /// Creates the ViewModel with a MenuService dependency
    /// - Parameter menuService: Service for menu API and filtering
    init(menuService: MenuService) {
        self.menuService = menuService
    }

    // MARK: - Data Loading

    /// Fetches all menu items for the given restaurant
    /// - Parameter restaurantId: The restaurant whose menu to load
    func loadMenu(restaurantId: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            allItems = try await menuService.fetchMenuItems(restaurantId: restaurantId)
            print("✅ MenuViewModel: Loaded \(allItems.count) items")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ MenuViewModel: Failed — \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refreshes menu items (clears existing data then reloads)
    func refresh(restaurantId: String) async {
        allItems = []
        await loadMenu(restaurantId: restaurantId)
    }

    // MARK: - Filter Actions

    /// Toggles a dietary tag on/off in the active filter set
    /// - Parameter tag: The dietary tag to toggle
    func toggleDietaryFilter(_ tag: DietaryTag) {
        if selectedDietaryFilters.contains(tag) {
            selectedDietaryFilters.remove(tag)
        } else {
            selectedDietaryFilters.insert(tag)
        }
    }

    /// Removes all active filters and clears the search query
    func clearFilters() {
        searchQuery = ""
        selectedDietaryFilters = []
        showAvailableOnly = false
    }
}
