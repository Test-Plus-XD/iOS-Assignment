//
//  SearchViewModel.swift
//  Pour Rice
//
//  ViewModel for the search screen
//  Manages Algolia search queries, filter state, and debounced search execution
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

/// ViewModel for the SearchView
/// Manages restaurant search, filtering, and result state
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

    /// Search results from Algolia
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
    // Filters narrow down search results by cuisine, price, and rating.
    // These match the Android app's SearchFilters model.

    /// Whether the filter sheet is currently presented
    var showingFilters = false

    /// Selected cuisine types to filter by (e.g., ["Italian", "Japanese"])
    var selectedCuisines: Set<String> = []

    /// Selected price ranges (e.g., ["$", "$$"])
    var selectedPriceRanges: Set<String> = []

    /// Minimum rating filter (0.0 = no filter, 4.0 = 4+ stars)
    var minimumRating: Double = 0

    /// Whether any filters are currently active
    var hasActiveFilters: Bool {
        !selectedCuisines.isEmpty || !selectedPriceRanges.isEmpty || minimumRating > 0
    }

    // MARK: - Dependencies

    /// Algolia search service for fast full-text restaurant search
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

    /// Performs a debounced search with the current query and filters
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
            // Wait 300ms before performing the search
            // If Task is cancelled during this sleep, it exits silently
            //
            // WHY try?:
            // Task.sleep throws CancellationError when cancelled.
            // try? converts the error to nil and exits the guard.
            try? await Task.sleep(for: .milliseconds(Constants.Search.debounceDelay))

            // Check if task was cancelled during sleep
            // If yes, do not proceed with search
            guard !Task.isCancelled else { return }

            // Perform the actual search
            await performSearch()
        }
    }

    /// Executes the Algolia search with current query and filters
    private func performSearch() async {
        isLoading = true
        errorMessage = nil

        do {
            // Build search filters from current filter state
            let filters = SearchFilters(
                cuisines: selectedCuisines.isEmpty ? nil : Array(selectedCuisines),
                priceRanges: selectedPriceRanges.isEmpty ? nil : Array(selectedPriceRanges),
                minRating: minimumRating > 0 ? minimumRating : nil
            )

            // Perform Algolia search (fast, indexed, typo-tolerant)
            let results = try await algoliaService.search(
                query: searchQuery,
                filters: filters,
                location: nil   // No geo-filter on search screen (user can browse globally)
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
        // Re-run search with updated filters
        if !searchQuery.isEmpty {
            await performSearch()
        }
    }

    /// Clears all active filters and re-runs the search
    func clearFilters() async {
        selectedCuisines = []
        selectedPriceRanges = []
        minimumRating = 0
        if !searchQuery.isEmpty {
            await performSearch()
        }
    }

    // MARK: - Available Filter Options
    //
    // These constants define the selectable values in the filter sheet.
    // Matching the Android app's filter options.

    /// Available cuisine types for filtering
    static let availableCuisines = [
        "Chinese", "Japanese", "Korean", "Thai", "Vietnamese",
        "Italian", "American", "Indian", "Mediterranean", "Fusion"
    ]

    /// Available price ranges for filtering
    static let availablePriceRanges = ["$", "$$", "$$$", "$$$$"]
}
