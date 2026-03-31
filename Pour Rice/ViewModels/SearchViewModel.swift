//
//  SearchViewModel.swift
//  Pour Rice
//
//  ViewModel for the search screen
//  Manages Vercel Algolia search queries, filter state, and debounced search execution
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This ViewModel shows a key iOS async pattern: debounced search using
//  Task cancellation — no external library needed.
//
//  DEBOUNCE PATTERN:
//  Every keystroke cancels the previous search task and schedules a new one.
//  After 300ms of no typing, the task runs. This prevents flooding the API.
//
//  FLUTTER EQUIVALENT:
//  final _searchController = StreamController<String>();
//  _searchController.stream
//    .debounceTime(Duration(milliseconds: 300))
//    .listen((query) => _performSearch(query));
//  ============================================================================
//

import Foundation
import Observation

// MARK: - Search View Model

/// ViewModel for the SearchView.
/// Manages restaurant search, district/keyword filtering, and result state.
///
/// Implements debounced search: waits 300ms after last keystroke before searching.
/// This prevents excessive API calls while typing.
@MainActor
@Observable
final class SearchViewModel {

    // MARK: - Search State

    /// Current search query text (bound to search bar)
    /// Changes to this property automatically trigger a debounced search
    var searchQuery = ""

    /// Accumulated search results across all loaded pages
    var searchResults: [Restaurant] = []

    /// Whether a search is currently in progress (first page)
    var isLoading = false

    /// Whether an additional page is being fetched (for infinite scroll)
    var isFetchingNextPage = false

    /// Error message if search failed
    var errorMessage: String?

    /// Whether the user has performed at least one search
    /// Used to differentiate "initial state" from "empty results"
    var hasSearched = false

    /// Toast message to display
    var toastMessage = ""

    /// Toast visual style
    var toastStyle: ToastStyle = .success

    /// Whether the toast is currently visible
    var showToast = false

    // MARK: - Pagination State

    /// The zero-based index of the last page that was loaded
    private var currentPage = 0

    /// Total number of pages available for the current query and filters
    private var totalPages = 1

    /// True when there are more pages available to fetch
    var hasMorePages: Bool { currentPage + 1 < totalPages }

    // MARK: - Filter State
    //
    // Filters narrow down search results by Hong Kong district and keyword tag.
    // These map directly to the Vercel Algolia endpoint's query parameters.

    /// Whether the filter sheet is currently presented
    var showingFilters = false

    /// Selected Hong Kong districts to filter by (e.g., ["Central", "Wan Chai"])
    var selectedDistricts: Set<String> = []

    /// Selected keyword tags to filter by (e.g., ["Vegan", "Organic"])
    var selectedKeywords: Set<String> = []

    /// Whether any filters are currently active
    var hasActiveFilters: Bool {
        !selectedDistricts.isEmpty || !selectedKeywords.isEmpty
    }

    // MARK: - Dependencies

    /// Restaurant service (includes Vercel-proxied Algolia search)
    private let restaurantService: RestaurantService

    /// Task handle for the current search — cancelled on each new keystroke
    ///
    /// WHAT IS Task?:
    /// Represents an async operation in Swift's concurrency system.
    /// Like a Future in Flutter or Coroutine Job in Kotlin.
    /// Calling .cancel() stops it early.
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialisation

    init(restaurantService: RestaurantService) {
        self.restaurantService = restaurantService
    }

    // MARK: - Search

    /// Performs a debounced search with the current query and filters.
    ///
    /// HOW DEBOUNCING WORKS:
    /// 1. User types a character → searchQueryChanged() is called
    /// 2. Any existing search task is cancelled
    /// 3. A new task starts and waits 300ms
    /// 4. If no more characters are typed in 300ms, search executes
    /// 5. If user types again before 300ms, go back to step 2
    ///
    /// WHY THIS PREVENTS API FLOODING:
    /// Typing "sushi" (5 chars) with no debounce = 5 API calls
    /// Typing "sushi" (5 chars) with 300ms debounce = 1 API call
    func searchQueryChanged() {
        // Cancel any pending search
        searchTask?.cancel()

        // Clear results if query is too short
        guard searchQuery.count >= Constants.Search.minQueryLength || searchQuery.isEmpty else {
            return
        }

        // Schedule new debounced search
        searchTask = Task {
            // Wait 300ms before performing the search.
            // If Task is cancelled during this sleep, it exits silently.
            try? await Task.sleep(for: .milliseconds(Constants.Search.debounceDelay))

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }

            await performSearch()
        }
    }

    /// Executes the Vercel Algolia search with current query and filters.
    /// Always fetches page 0 and resets accumulated results.
    private func performSearch() async {
        isLoading = true
        errorMessage = nil

        do {
            // Build search filters from current district/keyword selection
            let filters = SearchFilters(
                districts: selectedDistricts.isEmpty ? [] : Array(selectedDistricts),
                keywords: selectedKeywords.isEmpty ? [] : Array(selectedKeywords)
            )

            // Fetch the first page via Vercel proxy (fast, indexed, typo-tolerant)
            let result = try await restaurantService.search(
                query: searchQuery,
                filters: filters,
                page: 0
            )

            searchResults = result.restaurants
            currentPage = 0
            totalPages = result.totalPages

        } catch {
            // Only show error if task was not cancelled
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                showToast(String(localized: "toast_search_failed", bundle: L10n.bundle), .error)
                print("❌ Search failed: \(error.localizedDescription)")
            }
        }

        isLoading = false
        hasSearched = true
    }

    /// Fetches the next page of results and appends them to `searchResults`.
    /// Called when the user scrolls to the bottom of the results list.
    ///
    /// No-op if already loading, fetching, or no more pages are available.
    func loadNextPage() {
        guard hasMorePages, !isLoading, !isFetchingNextPage else { return }

        isFetchingNextPage = true

        Task {
            defer { isFetchingNextPage = false }

            do {
                let filters = SearchFilters(
                    districts: selectedDistricts.isEmpty ? [] : Array(selectedDistricts),
                    keywords: selectedKeywords.isEmpty ? [] : Array(selectedKeywords)
                )

                let nextPage = currentPage + 1
                let result = try await restaurantService.search(
                    query: searchQuery,
                    filters: filters,
                    page: nextPage
                )

                searchResults.append(contentsOf: result.restaurants)
                currentPage = nextPage
                totalPages = result.totalPages

            } catch {
                if !Task.isCancelled {
                    print("❌ Failed to load next page: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Filters

    /// Loads initial Algolia results (empty query = all records) when the Search tab first appears.
    func loadInitialResults() async {
        await performSearch()
    }

    /// Applies the current filter selections and re-runs the search
    func applyFilters() async {
        showingFilters = false
        await performSearch()
    }

    /// Clears all active filters and re-runs the search
    func clearFilters() async {
        selectedDistricts = []
        selectedKeywords = []
        await performSearch()
    }

    // MARK: - Available Filter Options
    //
    // These constants define the selectable values shown in the filter sheet.

    /// Available Hong Kong districts for filtering (loaded from filter_districts.json)
    static let availableDistricts: [LocalDataLoader.BilingualEntry] = LocalDataLoader.loadFilterDistricts()

    /// Available keyword tags for filtering (loaded from filter_keywords.json)
    static let availableKeywords: [LocalDataLoader.BilingualEntry] = LocalDataLoader.loadFilterKeywords()

    // MARK: - Private Helpers

    private func showToast(_ message: String, _ style: ToastStyle) {
        toastMessage = message
        toastStyle = style
        showToast = true
    }
}
