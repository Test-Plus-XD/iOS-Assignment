//
//  SearchView.swift
//  Pour Rice
//
//  Restaurant search screen powered by the Vercel Algolia proxy endpoint
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
import CoreLocation

// MARK: - Search View

/// Full-featured restaurant search screen powered by the Vercel Algolia proxy
///
/// Features:
/// - Live search with 300ms debounce
/// - District and keyword filters
/// - Empty and error states
/// - Navigation to restaurant detail screens
struct SearchView: View {

    // MARK: - Environment

    @Environment(\.services) private var services

    // MARK: - State

    @State private var viewModel: SearchViewModel?

    /// Tracks language changes to force BilingualText re-evaluation
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"

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
        .navigationTitle("search_title")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Initialise ViewModel with services from environment
            if viewModel == nil {
                viewModel = SearchViewModel(restaurantService: services.restaurantService)
                // Load all Algolia records immediately (empty query = browse all)
                await viewModel?.loadInitialResults()
            }
        }
        .toast(message: viewModel?.toastMessage ?? "", style: viewModel?.toastStyle ?? .success, isPresented: Binding(
            get: { viewModel?.showToast ?? false },
            set: { viewModel?.showToast = $0 }
        ))
    }

    // MARK: - Search Content

    @ViewBuilder
    private func searchContent(vm: SearchViewModel) -> some View {
        List {
            // Show results, loading, or empty/initial state
            if vm.isLoading {
                // Loading state — show inline spinner
                InlineLoadingView(label: "search_loading")
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
                        SearchResultRow(
                            restaurant: restaurant,
                            userLocation: services.locationService.currentLocation
                        )
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

                // Pagination sentinel — triggers next-page fetch when it scrolls into view
                if vm.hasMorePages {
                    HStack {
                        Spacer()
                        if vm.isFetchingNextPage {
                            ProgressView()
                                .padding(.vertical, Constants.UI.spacingMedium)
                        }
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onAppear {
                        vm.loadNextPage()
                    }
                }
            }
        }
        .listStyle(.plain)
        .id(preferredLanguage)
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
            prompt: "search_placeholder"
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
                .foregroundStyle(vm.hasActiveFilters ? Color.accentColor : .primary)
        }
        .accessibilityLabel("search_filter_button")
    }

    // MARK: - Initial Prompt View

    /// Displayed before the user has entered a search query
    private var initialPromptView: some View {
        VStack(spacing: Constants.UI.spacingMedium) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("search_prompt_title")
                .font(.title3)
                .fontWeight(.semibold)

            Text("search_prompt_message")
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
    var userLocation: CLLocation?

    var body: some View {
        HStack(spacing: 14) {

            // Rounded thumbnail with open/closed overlay
            ZStack(alignment: .bottomLeading) {
                AsyncImageView(
                    url: restaurant.imageURLs.first,
                    contentMode: .fill,
                    cornerRadius: Constants.UI.cornerRadiusLarge,
                    aspectRatio: 1
                )
                .frame(width: 80, height: 80)

                // Open/Closed pill — only when opening hours are available
                if !restaurant.openingHours.isEmpty {
                    Text(restaurant.isOpenNow
                         ? "open_now"
                         : "closed")
                        .font(.system(size: 9, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            restaurant.isOpenNow
                                ? Color.accentColor.opacity(0.9)
                                : Color.secondary.opacity(0.7),
                            in: Capsule()
                        )
                        .padding(5)
                }
            }
            .frame(width: 80, height: 80)
            .clipped()

            // Restaurant details
            VStack(alignment: .leading, spacing: 6) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
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

                HStack(spacing: 10) {
                    // Rating with accent background
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text(restaurant.ratingDisplay)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.85), in: Capsule())

                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Distance
                    if let distance = restaurant.distance(from: userLocation) {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            DistanceBadge.label(meters: distance)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(Constants.UI.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.accentColor.opacity(0.08), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge)
                .strokeBorder(Color.accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView()
            .environment(\.services, Services())
    }
}
