//
//  HomeView.swift
//  Pour Rice
//
//  Home screen showing featured restaurant carousel and nearby restaurant list
//  Entry point for restaurant discovery with location-aware results
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  This is equivalent to a Flutter StatefulWidget with a ChangeNotifier.
//  Key iOS/SwiftUI differences:
//
//  @State → local state owned by this view
//  @Environment → dependency injection (like Provider/context.read())
//  NavigationLink → like Navigator.push() but declarative
//  .task { } → runs async code when view appears (like initState() + async)
//  .refreshable { } → pull-to-refresh (like RefreshIndicator in Flutter)
//  ScrollView + LazyVStack → like SingleChildScrollView + Column (lazy)
//  ============================================================================
//

import SwiftUI

// MARK: - Home View

/// Main home screen with featured restaurant carousel and nearby restaurant list
///
/// ARCHITECTURE:
/// HomeView reads from HomeViewModel (created via @State)
/// and delegates business logic to the ViewModel.
/// The view only handles presentation — no business logic lives here.
///
/// NAVIGATION:
/// Uses NavigationLink(value:) + .navigationDestination(for:) for type-safe navigation.
/// Tapping a restaurant pushes RestaurantView onto the NavigationStack.
struct HomeView: View {

    // MARK: - Environment

    /// App-wide services (auth, API, location, etc.)
    /// Injected by Pour_RiceApp.swift and passed through the view hierarchy
    @Environment(\.services) private var services

    // MARK: - State

    /// ViewModel managing data and business logic for this screen
    ///
    /// WHAT IS @State:
    /// Declares local state owned by this view.
    /// When the value changes, SwiftUI rebuilds the view.
    ///
    /// WHY WE INITIALISE HERE:
    /// The ViewModel is created fresh when this view first appears.
    /// Services are injected via Environment, so we create the VM in .task{}
    @State private var viewModel: HomeViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(message: String(localized: "home_loading"))
            }
        }
        .navigationTitle(String(localized: "home_title"))
        .navigationBarTitleDisplayMode(.large)
        // .task runs async code when this view appears on screen
        // Equivalent to initState() + async operation in Flutter
        // Cancelled automatically when view disappears
        .task {
            // Initialise ViewModel with injected services (first appearance only)
            if viewModel == nil {
                let vm = HomeViewModel(
                    restaurantService: services.restaurantService,
                    locationService: services.locationService
                )
                viewModel = vm
                await vm.loadData()
            }
        }
    }

    // MARK: - Content

    /// Main content view once the ViewModel is ready
    @ViewBuilder
    private func content(vm: HomeViewModel) -> some View {
        if vm.isLoading && !vm.hasLoadedOnce {
            // Initial load — show full-screen loading
            LoadingView(message: String(localized: "home_loading"))

        } else if let error = vm.errorMessage, vm.featuredRestaurants.isEmpty, vm.nearbyRestaurants.isEmpty {
            // Error state with retry button
            ErrorView(message: error) {
                Task { await vm.loadData() }
            }

        } else {
            // Main content — scrollable list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {

                    // ─── Featured Restaurants Carousel ───────────────────
                    if !vm.featuredRestaurants.isEmpty {
                        featuredSection(restaurants: vm.featuredRestaurants)
                    }

                    // ─── Nearby Restaurants List ──────────────────────────
                    nearbySection(restaurants: vm.nearbyRestaurants, isLoading: vm.isLoading)

                }
            }
            // Pull-to-refresh support
            // User pulls down → calls vm.refresh() asynchronously
            //
            // FLUTTER EQUIVALENT:
            // RefreshIndicator(onRefresh: () => vm.refresh(), child: ...)
            .refreshable {
                await vm.refresh()
            }
        }
    }

    // MARK: - Featured Section

    /// Horizontal scrolling carousel of featured restaurants
    @ViewBuilder
    private func featuredSection(restaurants: [Restaurant]) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Section header
            Text(String(localized: "home_featured_title"))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.top, Constants.UI.spacingMedium)

            // Horizontal scroll of featured restaurant cards
            // ScrollView(.horizontal) = horizontal scrolling (like PageView/ListView in Flutter)
            ScrollView(.horizontal, showsIndicators: false) {
                // HStack arranges cards horizontally (like Row in Flutter)
                HStack(spacing: Constants.UI.spacingMedium) {
                    ForEach(restaurants) { restaurant in
                        // NavigationLink(value:) declares a navigation destination
                        // When tapped, pushes RestaurantView onto the NavigationStack
                        //
                        // FLUTTER EQUIVALENT:
                        // GestureDetector(
                        //   onTap: () => Navigator.push(context, MaterialPageRoute(
                        //     builder: (ctx) => RestaurantView(restaurant: restaurant)
                        //   )),
                        //   child: FeaturedRestaurantCard(restaurant: restaurant),
                        // )
                        NavigationLink(value: restaurant) {
                            FeaturedRestaurantCard(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)  // Removes default button styling
                        .hapticFeedback(style: .light)
                        .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars, \(restaurant.isOpenNow ? String(localized: "open_now") : String(localized: "closed"))")
                    }
                }
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.bottom, Constants.UI.spacingMedium)
            }
        }
    }

    // MARK: - Nearby Section

    /// Vertical list of nearby restaurants
    @ViewBuilder
    private func nearbySection(restaurants: [Restaurant], isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {

            // Section header
            Text(String(localized: "home_nearby_title"))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.top, Constants.UI.spacingMedium)

            if isLoading {
                InlineLoadingView(label: String(localized: "home_loading_nearby"))
            } else if restaurants.isEmpty {
                EmptyStateView.noNearbyRestaurants()
                    .frame(height: 200)
            } else {
                // List of nearby restaurants
                // LazyVStack only renders visible rows (better performance)
                LazyVStack(spacing: 0) {
                    ForEach(restaurants) { restaurant in
                        NavigationLink(value: restaurant) {
                            RestaurantRowView(restaurant: restaurant)
                                .padding(.horizontal, Constants.UI.spacingMedium)
                                .padding(.vertical, Constants.UI.spacingSmall)
                        }
                        .buttonStyle(.plain)
                        .hapticFeedback(style: .light)
                        .accessibilityLabel("\(restaurant.name.localised), \(restaurant.cuisine.localised), \(restaurant.ratingDisplay) stars")

                        // Divider between rows (like Divider() in Flutter)
                        Divider()
                            .padding(.leading, Constants.UI.spacingMedium)
                    }
                }
            }
        }
        .padding(.bottom, Constants.UI.spacingLarge)
    }
}

// MARK: - Featured Restaurant Card

/// Large horizontal card for the featured restaurants carousel
///
/// Shows the restaurant image, name, cuisine type, and rating.
/// Tappable to navigate to the restaurant detail screen.
private struct FeaturedRestaurantCard: View {

    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Restaurant image (hero-style with gradient overlay)
            ZStack(alignment: .bottomLeading) {
                RestaurantCardImage(urlString: restaurant.imageURLs.first)
                    .frame(width: 280, height: 160)

                // Rating badge overlaid on the image
                RatingBadge(rating: restaurant.rating)
                    .padding(Constants.UI.spacingSmall)
            }

            // Restaurant info below the image
            VStack(alignment: .leading, spacing: 4) {

                // Restaurant name (bilingual — shows current language automatically)
                Text(restaurant.name.localised)
                    .font(.headline)
                    .lineLimit(1)

                // Cuisine type
                Text(restaurant.cuisine.localised)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Price range + open/closed status
                HStack {
                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Open/Closed indicator
                    Text(restaurant.isOpenNow
                         ? String(localized: "open_now")
                         : String(localized: "closed"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(restaurant.isOpenNow ? .green : .red)
                }
            }
            .padding(Constants.UI.spacingSmall)
        }
        .frame(width: 280)
        // White card background with rounded corners and shadow
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusLarge))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Restaurant Row View

/// Compact horizontal row view for restaurant lists
///
/// Shows thumbnail image, name, cuisine, rating, and distance.
/// Used in the nearby restaurants section.
private struct RestaurantRowView: View {

    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: Constants.UI.spacingMedium) {

            // Square thumbnail image
            AsyncImageView(
                url: restaurant.imageURLs.first,
                contentMode: .fill,
                cornerRadius: Constants.UI.cornerRadiusMedium,
                aspectRatio: 1
            )
            .frame(width: 72, height: 72)

            // Restaurant info
            VStack(alignment: .leading, spacing: 4) {

                Text(restaurant.name.localised)
                    .font(.headline)
                    .lineLimit(1)

                Text(restaurant.cuisine.localised)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack {
                    // Star + rating
                    Label(restaurant.ratingDisplay, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(restaurant.priceRangeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Open/Closed
                    Text(restaurant.isOpenNow
                         ? String(localized: "open_now")
                         : String(localized: "closed"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(restaurant.isOpenNow ? .green : .secondary)
                }
            }

            // Disclosure chevron (standard iOS navigation indicator)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Rating Badge

/// Small yellow rating badge overlaid on restaurant images
private struct RatingBadge: View {

    let rating: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        // Capsule = pill shape
        .background(.black.opacity(0.6), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
            .environment(\.services, Services())
            .environment(\.authService, Services().authService)
    }
}
