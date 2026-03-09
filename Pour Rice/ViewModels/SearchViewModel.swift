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

    /// Search results from the Vercel Algolia proxy endpoint
    var searchResults: [Restaurant] = []

    /// Whether a search is currently in progress
    var isLoading = false

    /// Error message if search failed
    var errorMessage: String?

    /// Whether the user has performed at least one search
    /// Used to differentiate "initial state" from "empty results"
    var hasSearched = false

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

    /// Vercel-proxied Algolia search service
    private let algoliaService: AlgoliaService

    /// Task handle for the current search — cancelled on each new keystroke
    ///
    /// WHAT IS Task?:
    /// Represents an async operation in Swift's concurrency system.
    /// Like a Future in Flutter or Coroutine Job in Kotlin.
    /// Calling .cancel() stops it early.
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialisation

    init(algoliaService: AlgoliaService) {
        self.algoliaService = algoliaService
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

        // If query is empty, clear results without searching
        if searchQuery.isEmpty {
            searchResults = []
            hasSearched = false
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

    /// Executes the Vercel Algolia search with current query and filters
    private func performSearch() async {
        isLoading = true
        errorMessage = nil

        do {
            // Build search filters from current district/keyword selection
            let filters = SearchFilters(
                districts: selectedDistricts.isEmpty ? [] : Array(selectedDistricts),
                keywords: selectedKeywords.isEmpty ? [] : Array(selectedKeywords)
            )

            // Perform search via Vercel proxy (fast, indexed, typo-tolerant)
            let results = try await algoliaService.search(
                query: searchQuery,
                filters: filters
            )

            searchResults = results

        } catch {
            // Only show error if task was not cancelled
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                print("❌ Search failed: \(error.localizedDescription)")
            }
        }

        isLoading = false
        hasSearched = true
    }

    // MARK: - Filters

    /// Applies the current filter selections and re-runs the search
    func applyFilters() async {
        showingFilters = false
        if !searchQuery.isEmpty {
            await performSearch()
        }
    }

    /// Clears all active filters and re-runs the search
    func clearFilters() async {
        selectedDistricts = []
        selectedKeywords = []
        if !searchQuery.isEmpty {
            await performSearch()
        }
    }

    // MARK: - Available Filter Options
    //
    // These constants define the selectable values shown in the filter sheet.

    /// Available Hong Kong districts for filtering
    static let availableDistricts = [
        "Central", "Wan Chai", "Causeway Bay", "Mong Kok",
        "Tsim Sha Tsui", "Sham Shui Po", "Sha Tin", "Tuen Mun",
        "Yuen Long", "North"
    ]

    /// Available keyword tags for filtering (vegetarian cuisine focus)
    static let availableKeywords = [
        "Vegan", "Vegetarian", "Organic", "Dim Sum", "Hot Pot",
        "Noodles", "Rice", "Seafood", "Healthy", "Fusion"
    ]
}
