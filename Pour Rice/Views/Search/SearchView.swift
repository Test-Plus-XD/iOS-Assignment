//
//  SearchView.swift
//  Pour Rice
//
//  Restaurant search screen with live Algolia-powered search and filter support
//  Implements debounced search to avoid excessive API calls while typing
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  - .searchable() is iOS's built-in search bar in a NavigationStack
//  - .sheet() = ModalBottomSheet or showDialog() in Flutter
//  - .onChange(of:) = reactive listener (like stream.listen() in Dart)
//  - NavigationLink(value:) = Navigator.push() but declarative
//  ============================================================================
//

import SwiftUI

// MARK: - Search View

/// Full-featured restaurant search screen powered by Algolia
///
/// Features:
/// - Live search with 300ms debounce
/// - Cuisine, price range, and rating filters
/// - Empty and error states
/// - Navigation to restaurant detail screens
struct SearchView: View {

    // MARK: - Environment

    @Environment(\.services) private var services

    // MARK: - State

    @State private var viewModel: SearchViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                searchContent(vm: vm)
            } else {
                // ViewModel not yet initialised — show nothing while task starts
                Color.clear
            }
        }
        .navigationTitle(String(localized: "search_title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Initialise ViewModel with services from environment
            if viewModel == nil {
                viewModel = SearchViewModel(algoliaService: services.algoliaService)
            }
        }
    }

    // MARK: - Search Content

    @ViewBuilder
    private func searchContent(vm: SearchViewModel) -> some View {
        List {
            // Show results, loading, or empty/initial state
            if vm.isLoading {
                // Loading state — show inline spinner
                InlineLoadingView(label: String(localized: "search_loading"))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

            } else if let error = vm.errorMessage {
                // Error state
                ErrorView(message: error) {
                    Task { vm.searchQueryChanged() }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .frame(height: 300)

            } else if vm.searchResults.isEmpty && vm.hasSearched {
                // No results found for the query
                EmptyStateView.noSearchResults {
                    Task { await vm.clearFilters() }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .frame(height: 300)

            } else if !vm.hasSearched {
                // Initial state — prompt the user to search
                initialPromptView
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

            } else {
                // Search results list
                ForEach(vm.searchResults) { restaurant in
                    NavigationLink(value: restaurant) {
                        SearchResultRow(restaurant: restaurant)
                    }
                    .hapticFeedback(style: .light)
                    .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars")
                    .listRowInsets(EdgeInsets(
                        top: Constants.UI.spacingSmall,
                        leading: Constants.UI.spacingMedium,
                        bottom: Constants.UI.spacingSmall,
                        trailing: Constants.UI.spacingMedium
                    ))
                }
            }
        }
        .listStyle(.plain)
        // .searchable() adds iOS native search bar to the NavigationStack
        // Binds to vm.searchQuery (two-way binding with $)
        //
        // FLUTTER EQUIVALENT:
        // TextField with a search icon, updating state on each change
        .searchable(
            text: Binding(
                get: { vm.searchQuery },
                set: { vm.searchQuery = $0 }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: String(localized: "search_placeholder")
        )
        // .onChange fires whenever vm.searchQuery changes
        // Calls debounced search on each keystroke
        //
        // FLUTTER EQUIVALENT:
        // TextField.onChanged: (value) => vm.searchQueryChanged()
        .onChange(of: vm.searchQuery) { _, _ in
            vm.searchQueryChanged()
        }
        // Toolbar item for filter button
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterButton(vm: vm)
            }
        }
        // Filter sheet presented when showingFilters is true
        // .sheet() = modal bottom sheet in Flutter
        .sheet(isPresented: Binding(
            get: { vm.showingFilters },
            set: { vm.showingFilters = $0 }
        )) {
            FilterView(viewModel: vm)
        }
    }

    // MARK: - Filter Button

    /// Toolbar button to open the filter sheet
    /// Shows an active indicator badge when filters are applied
    private func filterButton(vm: SearchViewModel) -> some View {
        Button {
            vm.showingFilters = true
        } label: {
            // .overlay adds a small badge when filters are active
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(vm.hasActiveFilters ? .fill : .none)
                .foregroundStyle(vm.hasActiveFilters ? .accent : .primary)
        }
        .accessibilityLabel(String(localized: "search_filter_button"))
    }

    // MARK: - Initial Prompt View

    /// Displayed before the user has entered a search query
    private var initialPromptView: some View {
        VStack(spacing: Constants.UI.spacingMedium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(String(localized: "search_prompt_title"))
                .font(.title3)
                .fontWeight(.semibold)

            Text(String(localized: "search_prompt_message"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Search Result Row

/// List row showing a restaurant in search results
///
/// More compact than the home screen row, optimised for scan-reading.
private struct SearchResultRow: View {

    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: Constants.UI.spacingMedium) {

            // Thumbnail image
            AsyncImageView(
                url: restaurant.imageURLs.first,
                contentMode: .fill,
                cornerRadius: Constants.UI.cornerRadiusMedium,
                aspectRatio: 1
            )
            .frame(width: 64, height: 64)

            // Restaurant details
            VStack(alignment: .leading, spacing: 4) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(restaurant.cuisine.localised)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(restaurant.district.localised)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                HStack(spacing: 6) {
                    // Rating
                    Label(restaurant.ratingDisplay, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    // Price range
                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Open/Closed status
                    Text(restaurant.isOpenNow
                         ? String(localized: "open_now")
                         : String(localized: "closed"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(restaurant.isOpenNow ? .green : .secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView()
            .environment(\.services, Services())
    }
}
