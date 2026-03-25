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

    /// Controls whether the QR scanner full-screen cover is presented.
    /// Declared here (not in searchContent) because @State cannot be added inside
    /// a @ViewBuilder function — it must live on the View struct itself.
    ///
    /// The scanner is available to all user types (guests, diners, owners)
    /// because scanning a QR code just opens a public menu page.
    @State private var showingQRScanner = false

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
        // QR scanner full-screen cover.
        //
        // fullScreenCover (not .sheet) is used because:
        //  1. The camera viewfinder must fill the entire screen (no card-style modal)
        //  2. It matches the Android app's full-screen camera UX
        //
        // NavigationStack wrapper is REQUIRED so QRScannerView's .navigationDestination
        // can push MenuView after a successful scan. Without it, the push has no stack
        // to push onto and will be silently ignored by SwiftUI.
        .fullScreenCover(isPresented: $showingQRScanner) {
            NavigationStack {
                QRScannerView()
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
        // Toolbar items — filter (right) and QR scanner (right, second button)
        //
        // iOS renders multiple .topBarTrailing ToolbarItems left-to-right in declaration order,
        // so the scanner button appears to the LEFT of the filter button (further from the edge).
        // This matches common iOS patterns (e.g. iOS Camera app's options toolbar).
        .toolbar {
            // Filter button — already existed; opens the district/keyword filter sheet
            ToolbarItem(placement: .topBarTrailing) {
                filterButton(vm: vm)
            }

            // QR scanner button — opens full-screen camera to scan a restaurant's QR code.
            // camera.viewfinder is a natural icon choice: it communicates both
            // "camera" (scanning) and "frame/target" (aiming at a QR code).
            //
            // ANDROID EQUIVALENT:
            //   The QR scanner entry point in the Android app is in the navigation drawer:
            //   ListTile(leading: Icon(Icons.qr_code_scanner), ...)
            //   iOS has no drawer, so the toolbar is the closest equivalent.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingQRScanner = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                }
                .accessibilityLabel(Text("qr_scanner_open"))
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

            // Rounded thumbnail with open/closed and distance overlays
            ZStack {
                AsyncImageView(
                    url: restaurant.imageURLs.first,
                    contentMode: .fill,
                    cornerRadius: Constants.UI.cornerRadiusLarge,
                    aspectRatio: 1
                )
                .frame(width: 88, height: 88)

                VStack {
                    // Distance badge — top-left
                    HStack {
                        if let distance = restaurant.distance(from: userLocation) {
                            DistanceBadge(meters: distance)
                        }
                        Spacer()
                    }
                    Spacer()
                    // Open/Closed pill — bottom-left
                    HStack {
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
                        Spacer()
                    }
                }
                .padding(6)
            }
            .frame(width: 88, height: 88)
            .clipped()

            // Restaurant details
            VStack(alignment: .leading, spacing: 6) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !restaurant.keywords.isEmpty {
                    Text(restaurant.keywords.map { $0.localised }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(restaurant.district.localised)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(restaurant.address.localised)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
